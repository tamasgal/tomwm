public let stableTomWmAppId: String = "com.tamasgal.tomwm"
#if DEBUG
    public let tomWmAppId: String = "com.tamasgal.tomwm.debug"
    public let tomWmAppName: String = "TomWM-Debug"
#else
    public let tomWmAppId: String = stableTomWmAppId
    public let tomWmAppName: String = "TomWM"
#endif
