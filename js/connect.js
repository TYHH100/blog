(function() {
    const fullUrl = window.location.href;
    const baseUrl = window.location.origin;
    const path = fullUrl.replace(baseUrl, '');
    const prefix = "/connect/?server=";
    
    if (path.startsWith(prefix)) {
        const serverAddress = path.substring(prefix.length);
        const cleanAddress = serverAddress.split('?')[0].split('#')[0];
        
        if (cleanAddress.includes(':') && cleanAddress.split(':').length === 2) {
            window.location.href = "steam://connect/" + cleanAddress;
            return;
        }
    }
    window.location.href = "/";
})();