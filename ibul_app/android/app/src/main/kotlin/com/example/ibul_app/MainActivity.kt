package com.ibul.app

import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ibul.app/lan_center")
            .setMethodCallHandler { call, result ->
                if (call.method != "browse") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                browseLanCenters(result)
            }
    }

    private fun browseLanCenters(result: MethodChannel.Result) {
        val manager = getSystemService(NsdManager::class.java)
        val found = mutableListOf<Map<String, Any>>()
        var replied = false
        fun finish(discovery: NsdManager.DiscoveryListener) {
            if (replied) return
            replied = true
            try {
                manager.stopServiceDiscovery(discovery)
            } catch (_: Exception) {
            }
            result.success(found)
        }
        val discovery = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {}
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                finish(this)
            }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
            override fun onServiceLost(serviceInfo: NsdServiceInfo) {}
            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (!serviceInfo.serviceType.contains("_ibul-lan._tcp")) return
                manager.resolveService(serviceInfo, object : NsdManager.ResolveListener {
                    override fun onResolveFailed(info: NsdServiceInfo, errorCode: Int) {}
                    override fun onServiceResolved(info: NsdServiceInfo) {
                        val attributes = info.attributes ?: emptyMap()
                        fun text(key: String): String {
                            val bytes = attributes[key] ?: return ""
                            return bytes.toString(Charsets.UTF_8)
                        }
                        found.add(
                            mapOf(
                                "host" to (info.host?.hostAddress ?: ""),
                                "port" to info.port,
                                "restaurant_id" to text("rid"),
                                "machine_id" to text("mid"),
                                "fingerprint" to text("fp"),
                                "service" to text("svc"),
                            ),
                        )
                    }
                })
            }
        }
        manager.discoverServices("_ibul-lan._tcp.", NsdManager.PROTOCOL_DNS_SD, discovery)
        window.decorView.postDelayed({ finish(discovery) }, 2500)
    }
}
