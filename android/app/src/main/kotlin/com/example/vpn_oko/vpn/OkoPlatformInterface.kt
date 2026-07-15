package com.example.vpn_oko.vpn

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Process
import android.system.Os
import android.system.OsConstants
import com.example.vpn_oko.bridge.LogMessage
import com.example.vpn_oko.bridge.VpnEventBus
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

class OkoPlatformInterface(
    private val service: OkoVpnService,
    private val builderFactory: () -> VpnService.Builder,
) : PlatformInterface {

    private var monitorCallback: ConnectivityManager.NetworkCallback? = null
    private val monitorThread = HandlerThread("oko-net-monitor").apply { start() }
    private val monitorHandler = Handler(monitorThread.looper)
    private val syntheticIndexes = ConcurrentHashMap<String, Int>()
    private val syntheticIndexCounter = AtomicInteger(1000)

    override fun openTun(options: TunOptions): Int {
        val builder = builderFactory()
            .setSession("Oko VPN")
            .setMtu(options.mtu)

        var hasInet4 = false
        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            hasInet4 = true
            val address = inet4Address.next()
            builder.addAddress(address.address(), address.prefix())
        }

        var hasInet6 = false
        val inet6Address = options.inet6Address
        while (inet6Address.hasNext()) {
            hasInet6 = true
            val address = inet6Address.next()
            builder.addAddress(address.address(), address.prefix())
        }

        if (options.autoRoute) {
            runCatching {
                val dns = options.dnsServerAddress.value
                if (dns.isNotBlank()) builder.addDnsServer(dns)
            }

            val inet4Route = options.inet4RouteAddress
            if (inet4Route.hasNext()) {
                while (inet4Route.hasNext()) {
                    val route = inet4Route.next()
                    builder.addRoute(route.address(), route.prefix())
                }
            } else if (hasInet4) {
                builder.addRoute("0.0.0.0", 0)
            }

            val inet6Route = options.inet6RouteAddress
            if (inet6Route.hasNext()) {
                while (inet6Route.hasNext()) {
                    val route = inet6Route.next()
                    builder.addRoute(route.address(), route.prefix())
                }
            } else if (hasInet6) {
                builder.addRoute("::", 0)
            }

            val includePackage = options.includePackage
            while (includePackage.hasNext()) {
                runCatching { builder.addAllowedApplication(includePackage.next()) }
            }

            val excludePackage = options.excludePackage
            while (excludePackage.hasNext()) {
                runCatching { builder.addDisallowedApplication(excludePackage.next()) }
            }
        } else {
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0)
        }

        val descriptor = builder.establish()
            ?: throw IllegalStateException("android: vpn not prepared or revoked")
        service.attachTunnel(descriptor)
        return descriptor.fd
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {
        service.protect(fd)
    }

    override fun useProcFS(): Boolean = false

    override fun findConnectionOwner(
        ipProto: Int,
        srcIp: String,
        srcPort: Int,
        destIp: String,
        destPort: Int,
    ): ConnectionOwner {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException("android: connection owner requires api 29")
        }
        val manager = connectivity()
            ?: throw IllegalStateException("android: connectivity unavailable")
        val uid = manager.getConnectionOwnerUid(
            ipProto,
            InetSocketAddress(srcIp, srcPort),
            InetSocketAddress(destIp, destPort),
        )
        if (uid == Process.INVALID_UID) throw IllegalStateException("android: connection owner not found")
        val packages = service.packageManager.getPackagesForUid(uid)?.toList().orEmpty()
        return ConnectionOwner().apply {
            userId = uid
            userName = packages.firstOrNull().orEmpty()
            setAndroidPackageNames(StringList(packages))
        }
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val manager = connectivity() ?: return NetworkInterfaceList(emptyList())
        val interfaces = mutableListOf<LibboxNetworkInterface>()
        val networks = runCatching { manager.allNetworks }.getOrDefault(emptyArray())
        for (network in networks) {
            val linkProperties = manager.getLinkProperties(network) ?: continue
            val capabilities = manager.getNetworkCapabilities(network) ?: continue
            val name = linkProperties.interfaceName ?: continue
            val index = interfaceIndex(name)
            if (index == 0) continue
            val boxInterface = LibboxNetworkInterface()
            boxInterface.name = name
            boxInterface.index = index
            boxInterface.type = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                else -> Libbox.InterfaceTypeOther
            }
            boxInterface.dnsServer = StringList(linkProperties.dnsServers.mapNotNull { it.hostAddress })
            boxInterface.setAddresses(
                StringList(
                    linkProperties.linkAddresses.mapNotNull { entry ->
                        entry.address.hostAddress?.substringBefore('%')?.let { "$it/${entry.prefixLength}" }
                    },
                ),
            )
            runCatching { boxInterface.mtu = linkProperties.mtu }
            var flags = OsConstants.IFF_MULTICAST
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                flags = flags or OsConstants.IFF_UP or OsConstants.IFF_RUNNING
            }
            boxInterface.flags = flags
            boxInterface.metered =
                !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            interfaces.add(boxInterface)
        }
        return NetworkInterfaceList(interfaces)
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val manager = connectivity() ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
            .build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) = emitDefaultInterface(manager, network, listener)

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) =
                emitDefaultInterface(manager, network, listener)

            override fun onLost(network: Network) {
                listener.updateDefaultInterface("", -1, false, false)
            }
        }
        runCatching {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S ->
                    manager.registerBestMatchingNetworkCallback(request, callback, monitorHandler)
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.P ->
                    manager.requestNetwork(request, callback, monitorHandler)
                else ->
                    manager.registerDefaultNetworkCallback(callback, monitorHandler)
            }
        }.onSuccess { monitorCallback = callback }
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        val callback = monitorCallback ?: return
        monitorCallback = null
        runCatching { connectivity()?.unregisterNetworkCallback(callback) }
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {
    }

    override fun readWIFIState(): WIFIState = WIFIState("", "")

    override fun sendNotification(notification: Notification) {
        val title = notification.title.orEmpty()
        val body = notification.body.orEmpty()
        VpnEventBus.emit(LogMessage("$title $body".trim(), System.currentTimeMillis(), "info"))
    }

    override fun systemCertificates(): StringIterator = StringList(emptyList())

    override fun localDNSTransport(): LocalDNSTransport? = null

    private fun emitDefaultInterface(
        manager: ConnectivityManager,
        network: Network,
        listener: InterfaceUpdateListener,
    ) {
        for (attempt in 0 until 10) {
            val name = manager.getLinkProperties(network)?.interfaceName
            if (name == null) {
                Thread.sleep(100)
                continue
            }
            val index = interfaceIndex(name)
            if (index == 0) {
                Thread.sleep(100)
                continue
            }
            val capabilities = manager.getNetworkCapabilities(network)
            val expensive = capabilities != null &&
                !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            listener.updateDefaultInterface(name, index, expensive, false)
            return
        }
    }

    private fun interfaceIndex(name: String): Int {
        val real = runCatching { Os.if_nametoindex(name) }.getOrDefault(0)
        if (real != 0) return real
        return syntheticIndexes.getOrPut(name) { syntheticIndexCounter.getAndIncrement() }
    }

    private fun connectivity(): ConnectivityManager? =
        service.getSystemService(ConnectivityManager::class.java)

    private class StringList(private val values: List<String>) : StringIterator {
        private var index = 0
        override fun len(): Int = values.size
        override fun hasNext(): Boolean = index < values.size
        override fun next(): String = values[index++]
    }

    private class NetworkInterfaceList(
        private val values: List<LibboxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        private var index = 0
        override fun hasNext(): Boolean = index < values.size
        override fun next(): LibboxNetworkInterface = values[index++]
    }
}
