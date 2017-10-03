# Anti-Blocking System for http servers

There is a trend to block sites by different administrations and governments for critical publications. We don't like such blocking policy and generated some relatively easy idea to avoid such site blocking, and short [nginx](nginx.org) config to implement it.

The idea is not concerned to the IP address. Additional investigation should be done to create an anti-blocking idea for IP addresses.

## Anti-Blocking idea
The blocking rules are often based on the particular URL containing a site domain name and sometimes path (URI) to the restricted matherial. It means that the site as a whole is not blocked by this record, and administration restricts local access to the particular matherial on the site only.

Even when the domain is restricted, the particular domain is blocked.

The idea is to create an individual *matherial viewer URL* for **each** particular user reading **each** particular material.

When the restriction rule is created it refers to the informational matherial by the URL which the administration staff is seeing in the browser address line. If the URL refers not only to the matherial itself, but to the both, matherial and viewer, this URL will be individual to this particular administration staff seeing this particular matherial. So the restriction may be applied easy, but will be applied only for this particular staff.

The site admin person may be absolutely legal and immediately approve any such URL to be blocked: it has no any influence to other viewers which can see the original matherial as it was before. Number of URLs to the same matherial is equal to number of viewers and every such URL is individual to the viewer.

## Individual matherial viewer URL
When the matherial is requested by the particular viewer the individual matherial viewer URL is combined from the matherial URL and viewer identity. Viewer identity is stored in the special cookie. Way of URL transformation to combine matherial URL and viewer ID can vary.

### Individual viewer subdomain
Every viewer has it's own subdomain to see matherials, while the path to the matherial is permanent across viewers subdomains.

Such a way, the matherial having original matherial path `/a/b/c` will have the following references:
- `gwfhg.example.com/a/b/c` - for the viewer `gwfhg`
- `rtyrd.example.com/a/b/c` - for the viewer `rtyrd`
- `cvbcb.example.com/a/b/c` - for the viewer `cvbcb`
- etc.

### Individual viewer path prefix
Every viewer has it's own path prefix, the rest of the path is individual to the matherial

Such a way, the matherial having original matherial path `/a/b/c` will have the following references:
- `example.com/gwfhg/a/b/c` - for the viewer `gwfhg`
- `example.com/rtyrd/a/b/c` - for the viewer `rtyrd`
- `example.com/cvbcb/a/b/c` - for the viewer `cvbcb`
- etc.


### Combination of subdomain and path prefix
The pair of subdomain and path prefix is determined by the viewer identity, while th superdomain and the rest of the path concerns to the matherial

Such a way, the matherial having original matherial path `/a/b/c` will have the following references:
- `gwfhg.example.com/asdf/a/b/c` - for the viewer `asdf@gwfhg`
- `rtyrd.example.com/qwer/a/b/c` - for the viewer `qwer@rtyrd`
- `cvbcb.example.com/zxcv/a/b/c` - for the viewer `zxcv@cvbcb`
- etc.

### Encrypted subdomain and path
The subdomain and path are determined by some cryptographic function having viewer identity and original path as parameters

Such a way, the matherial having original matherial path `/a/b/c` will have the following references:
- `gwfhg.example.com/asdf` - for the viewer `12345`
- `rtyrd.example.com/qwer` - for the viewer `23456`
- `cvbcb.example.com/zxcv` - for the viewer `34567`
- etc.


## Persistent reference
Any viewer can send it's individual URL referencing to the matherial to any other viewer free. When the other viewer will open the received reference URL, it be redirected to it's individual matherial URL basing on the matherial path extracted from the first viewer individual URL and the second viewer individual identity.

Let the viewer `asdf@gwfhg` has stored it's individual URL reference `gwfhg.example.com/asdf`. Then it sends the reference to the matherial to the viewer `qwer@rtyrd`. When the viewer `qwer@rtyrd` requests a page from `gwfhg.example.com/asdf` the server converts the requested URL to `rtyrd.example.com/qwer` and redirects viewer `qwer@rtyrd` to this URL.

## Implementation
The pre-alpha implementation code concerns to generating URL from the combination of subdomain and path prefix individual to the viewer. In order to have unchanged backend code working as is, the root-relative URLs found on the returned page will be detected when requested.

The code refers to 3 different subdomains, a, b, and c, using them in the viewer identity and selecting them randomly for every viewer. Such restricted implementation has been selected for easy /etc/hosts simulating DNS. You can use wildcard A-record and extend subdomain selection to randomly generated string in production instead.

The code uses random 32-character hex path prefix as a part of the viewer identity. Such a prefix may lead to problems when using forms in case of unchanged backend code.

We will create a configuration to have a possibility to have a choice of matherial individual URL constructing algorithm and it's parameters at the next stage.
