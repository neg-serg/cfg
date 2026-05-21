#!/usr/bin/env python3
"""Salt log sanitizer — masks API keys and secrets before writing to log files.

Reads stdin, writes sanitized output to stdout.
Replaces known API key patterns with [REDACTED].
"""

import re
import sys

API_KEY_RE = re.compile(r'(?:csk|sk)-[a-z0-9]{30,}')
BEARER_RE = re.compile(r'(?:Bearer\s+)([a-zA-Z0-9._\-+/=]{20,})')


def sanitize(line: str) -> str:
    line = API_KEY_RE.sub('[REDACTED]', line)
    line = BEARER_RE.sub(r'Bearer [REDACTED]', line)
    return line


def main() -> None:
    try:
        for line in sys.stdin:
            sys.stdout.write(sanitize(line))
    except BrokenPipeError:
        pass
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    main()
