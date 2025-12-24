const String xdaoCdnAuto = 'auto';

/// Base CDN list (for JSON API).
///
/// NOTE: Some entries may redirect (30x). Network layer must preserve cookie
/// during redirects for login-required endpoints (e.g. timeline id=2).
const List<String> xdaoBaseCdns = [
  'https://api.nmb.best',
  'https://www.nmbxd.com',
  'https://www.nmbxd1.com',
  'https://api.nmb.fastmirror.org',
];

/// Ref CDN list (for HTML ref pages: /Home/Forum/ref?id=...).
const List<String> xdaoRefCdns = [
  'https://www.nmbxd.com',
  'https://www.nmbxd1.com',
];
