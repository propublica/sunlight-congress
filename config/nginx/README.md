The nginx configuration we use in production for the [Sunlight Congress API](http://sunlightlabs.github.io/congress/), spread across a few different files.


### Robust SSL support

We do our best to use SSL best practices in our Congress API, such as [perfect forward secrecy](https://www.eff.org/deeplinks/2013/08/pushing-perfect-forward-secrecy-important-web-privacy-protection).

Our nginx SSL rules can be found in [congress-api.conf](config/nginx/congress-api.conf).

You can use SSL Labs' testing tool to [check out how we measure up](https://www.ssllabs.com/ssltest/analyze.html?d=congress.api.sunlightfoundation.com) any time.

Note that our lack of [HSTS](http://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security) support is intentional, as we do currently continue to support plain HTTP requests.

### Suppressing latitude and longitude values

Our `/legislators/locate` and `/districts/locate` endpoints return location-specific information on Congressional representation based on a latitude and longitude, or a zip code.

Congressional representation may not in and of itself be a particularly sensitive issue, but latitude and longitude values are sensitive enough that it's worth limiting their ability to be connected to other values (such as an IP address).

Because of this, as of January 2014, we scrub any user-submitted latitude and longitude values from our nginx logs before they are written to disk. You can see the nginx instructions for this in:

* [nginx.config](), where we define a log format that will write a custom rewritten request variable

```nginx
log_format scrubbed '"$http_x_forwarded_for - $remote_user [$time_local]  '
    '"$scrubbed_request" $status $body_bytes_sent '
    '"$http_referer" "$http_user_agent"';
```

* [proxy.rules](), where we enable that log format, and perform the regex find/replace on request lines containing latitude and longitude parameters (adapted from [this StackOverflow answer](http://stackoverflow.com/a/19430297/16075))

```nginx
set $scrubbed_request $request;
if ($scrubbed_request ~ (.*)latitude=[^&]*(.*)) {
   set $scrubbed_request $1latitude=****$2;
}
if ($scrubbed_request ~ (.*)longitude=[^&]*(.*)) {
   set $scrubbed_request $1longitude=****$2;
}
```

Also, as of December 2013, we [do not store lat/lng data in our analytics database](https://github.com/sunlightlabs/congress/commit/872b0ee643da5d2ef28a0a77a9fc2187285c74d7#diff-1), and have some basic measures to [filter lat/lng out of application-level logging](https://github.com/sunlightlabs/congress/commit/00f3303a5fadce37259dbcb2e1c6973aaee88e79#diff-1) if it were ever turned on (which so far it has not been). As far as we're aware, latitude and longitude are not and should not be written to our servers' disks.

**Note**: We do continue to record IP addresses in our nginx logs, for network administration purposes. User-submitted zip codes are also logged.