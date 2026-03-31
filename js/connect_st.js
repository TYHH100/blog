(function() {
    const fullUrl = window.location.href;
    const baseUrl = window.location.origin;
    const path = fullUrl.replace(baseUrl, '');
    const prefix = "/blog/connect/?server=";
    
    if (path.startsWith(prefix)) {
        const serverAddress = path.substring(prefix.length);
        const cleanAddress = serverAddress.split('?')[0].split('#')[0];
        
        // 匹配域名或IP，可选端口（数字）
        const isValid = /^[a-zA-Z0-9.-]+(:[0-9]+)?$/.test(cleanAddress);
        
        if (isValid) {
            window.location.href = "steam://connect/" + cleanAddress;
            return;
        }
    }
    window.location.href = "/";
})();