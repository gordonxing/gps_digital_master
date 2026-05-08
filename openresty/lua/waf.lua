-- WAF (Web Application Firewall) for OpenResty
-- 功能：IP黑名单、请求限流、恶意URI过滤

local ngx = ngx
local shared_blacklist = ngx.shared.waf_ip_blacklist
local shared_rate = ngx.shared.waf_rate_limit
local shared_whitelist = ngx.shared.waf_whitelist

-- ============ 配置 ============
local CONFIG = {
    -- 限流配置（令牌桶）
    rate_limit = {
        requests_per_second = 50,    -- 每秒允许请求数
        burst = 100,                 -- 突发容量
    },
    -- 黑名单封禁时长（秒）
    ban_duration = 3600,
    -- 是否启用各模块
    enable_ip_blacklist = true,
    enable_rate_limit = true,
    enable_uri_filter = true,
}

-- ============ 白名单检查 ============
local function is_whitelisted(ip)
    if shared_whitelist then
        local val = shared_whitelist:get(ip)
        if val then
            return true
        end
    end
    -- 内网IP白名单
    if ip == "127.0.0.1" or ip:find("^10%.") or ip:find("^172%.1[6-9]%.") or
       ip:find("^172%.2%d%.") or ip:find("^172%.3[0-1]%.") or ip:find("^192%.168%.") then
        return true
    end
    return false
end

-- ============ IP 黑名单检查 ============
local function check_ip_blacklist(ip)
    if not CONFIG.enable_ip_blacklist then
        return false
    end
    if shared_blacklist then
        local blocked = shared_blacklist:get(ip)
        if blocked then
            ngx.log(ngx.WARN, "[WAF] IP blacklisted: ", ip)
            return true
        end
    end
    return false
end

-- ============ 令牌桶限流 ============
local function check_rate_limit(ip)
    if not CONFIG.enable_rate_limit then
        return false
    end

    local key = "rate:" .. ip
    local now = ngx.now()

    local last_time = shared_rate:get(key .. ":time") or now
    local tokens = shared_rate:get(key .. ":tokens") or CONFIG.rate_limit.burst

    -- 补充令牌
    local elapsed = now - last_time
    tokens = math.min(CONFIG.rate_limit.burst, tokens + elapsed * CONFIG.rate_limit.requests_per_second)

    -- 消耗一个令牌
    if tokens < 1 then
        ngx.log(ngx.WARN, "[WAF] Rate limit exceeded for IP: ", ip)
        -- 超限次数过多则加入黑名单
        local exceed_key = "exceed:" .. ip
        local exceed_count = (shared_rate:get(exceed_key) or 0) + 1
        shared_rate:set(exceed_key, exceed_count, 60)
        if exceed_count > 200 then
            shared_blacklist:set(ip, true, CONFIG.ban_duration)
            ngx.log(ngx.ERR, "[WAF] IP auto-banned: ", ip)
        end
        return true
    end

    tokens = tokens - 1
    shared_rate:set(key .. ":time", now, 60)
    shared_rate:set(key .. ":tokens", tokens, 60)

    return false
end

-- ============ URI 恶意请求过滤 ============
local MALICIOUS_PATTERNS = {
    -- SQL 注入
    "select%s+.*%s+from",
    "union%s+.*%s+select",
    "insert%s+into",
    "delete%s+from",
    "drop%s+table",
    "update%s+.*%s+set",
    "exec%s*%(",
    "execute%s*%(",
    "xp_cmdshell",
    "0x[0-9a-fA-F]+",

    -- XSS
    "<script",
    "javascript:",
    "onerror%s*=",
    "onload%s*=",
    "onclick%s*=",
    "eval%s*%(",
    "alert%s*%(",

    -- 路径穿越
    "%.%.%/",
    "%.%.\\",

    -- 常见扫描路径
    "/etc/passwd",
    "/proc/self",
    "wp%-admin",
    "wp%-login",
    "phpmyadmin",
    "%.env",
    "%.git/",
}

local function check_uri_filter(uri, args)
    if not CONFIG.enable_uri_filter then
        return false
    end

    local check_str = (uri .. "?" .. (args or "")):lower()

    for _, pattern in ipairs(MALICIOUS_PATTERNS) do
        if check_str:find(pattern) then
            ngx.log(ngx.WARN, "[WAF] Malicious pattern detected: ", pattern, " in: ", uri)
            return true
        end
    end

    return false
end

-- ============ 主逻辑 ============
local client_ip = ngx.var.remote_addr

-- 白名单直接放行
if is_whitelisted(client_ip) then
    return
end

-- IP 黑名单检查
if check_ip_blacklist(client_ip) then
    ngx.status = 403
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error":"Forbidden","message":"Your IP has been blocked"}')
    return ngx.exit(403)
end

-- 限流检查
if check_rate_limit(client_ip) then
    ngx.status = 429
    ngx.header["Content-Type"] = "application/json"
    ngx.header["Retry-After"] = "60"
    ngx.say('{"error":"Too Many Requests","message":"Rate limit exceeded"}')
    return ngx.exit(429)
end

-- URI 恶意请求过滤
if check_uri_filter(ngx.var.request_uri, ngx.var.args) then
    ngx.status = 403
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error":"Forbidden","message":"Malicious request detected"}')
    return ngx.exit(403)
end
