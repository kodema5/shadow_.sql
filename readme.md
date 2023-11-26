# shadow_.sql

for simpler development cycle:
to safely "drop schema foo cascade" without losing production data.

to shadow:
a foo schema contains bar table and code
- creates foo_ schema
- foo_.bar inherits foo.bar
- adds an insert trigger on foo.bar that moves data to foo_.bar
- an optional event-trigger no-drop cancels dropping foo_

limitations:
- "insert foo.bar (...) on conflict ..." throws
