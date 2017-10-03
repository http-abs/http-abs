init_by_lua_block {

str = require "nginx.string";
rand = require "nginx.random";

local_subdomains = {'a','b','c'};

function random_domain()
    local i = math.random(#local_subdomains)
    return local_subdomains[i]
end

function random_id()
    local random = rand.bytes(16)
    return str.to_hex(random)
end

}


server {
        listen 80;
        listen [::]:80;

        server_name example.com;

        root /var/www/example.com;

        location / {
         # MIME type determined by default_type:
         default_type 'text/plain';

         content_by_lua_block {
            ngx.print("Cats here!")
         }
        }
}

server {
    listen 80;
    listen [::]:80;

    server_name *.example.com;

    root /var/www/example.com;

    location / {
        # URL-based viewer identity

        ## splitting subdomain and superdomain from domain
        set $superdomain '';
        set_by_lua_block $viewer_subdomain {
            local match = ngx.re.match(ngx.var.host,"^(?<viewer_subdomain>[^.]+)[.](?<superdomain>.*)$");
            ngx.var.superdomain = match['superdomain'];
            return match['viewer_subdomain'];
        }

        ## recognizing the viewer id from the uri
        set $original_uri $uri;
        set $arguments '';
        if ($args) {
            set $arguments ?$args;
        }
        set_by_lua_block $viewer_id {
            local match = ngx.re.match(ngx.var.uri,"^/(?<viewer_id>[a-f0-9]{32,32})(?<original_uri>(|/.*))$")
            if match then
                ngx.var.original_uri = match['original_uri']
                return match['viewer_id']
            end
            return '';
        }

        # Cookie-based viewer identity

        set $local_viewer_id '';
        set $local_viewer_subdomain '';
        if ($cookie_viewer_identity) {
            set_by_lua_block $local_viewer_id {
                local match = ngx.re.match(ngx.var.cookie_viewer_identity,"(?<local_viewer_id>.*)@(?<local_viewer_subdomain>.*)")
                if match then
                    ngx.var.local_viewer_subdomain = match['local_viewer_subdomain']
                    return match['local_viewer_id']
                end
                return ''
            }
        }

        # Create a new viewer identity if the local identity has been absent
        if ($local_viewer_id = '') {
            set_by_lua_block $local_viewer_subdomain {
                return random_domain()
            }
            set_by_lua_block $local_viewer_id {
                return random_id()
            }
            set_by_lua_block $client_identity_cookie {
                return 'viewer_identity='..ngx.var.local_viewer_id..'@'..ngx.var.local_viewer_subdomain..';path=/;domain='..ngx.var.superdomain
            }
            add_header Set-Cookie $client_identity_cookie;
            return 302 $scheme://$local_viewer_subdomain.$superdomain/$local_viewer_id$original_uri$arguments;
        }

        # Redirect if necessary
        set $redirect_required 0;
        if ($local_viewer_id != $viewer_id) {
            set $redirect_required 1;
        }
        if ($local_viewer_subdomain != $viewer_subdomain) {
            set $redirect_required 1;
        }
        if ($redirect_required) {
            return 302 $scheme://$local_viewer_subdomain.$superdomain/$local_viewer_id$original_uri$arguments;
        }

        # pass to the original backend

        # fix set-cookie path from the backend
        proxy_cookie_path   ~^(?P<original_cookie_uri>(|/.*))$ /$local_viewer_id$original_cookie_uri;

        # fix request path
        rewrite_by_lua_block {
            local uri
            if ngx.var.args then
                ngx.req.set_uri_args(ngx.var.args)
            end
            if ngx.var.original_uri == '' then
                uri = "/"
            else
                uri = ngx.var.original_uri
            end
            ngx.req.set_uri(uri)
        }

        # store some additional common-used headers while proxying for backend
        proxy_set_header X-Real-IP      $remote_addr;
        proxy_set_header User-Agent     $http_user_agent;
        proxy_set_header Host           $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://127.0.0.1:8000;
    }
}
