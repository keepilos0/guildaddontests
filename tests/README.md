# Automated checks

`run_checks.py` verifies:

- syntax of every first-party Lua file;
- all file references and loading order in the `.toc`;
- parity of English, Russian and Ukrainian localization keys;
- the GameAPI boundary for business modules;
- request/group limits, expiry, task confirmation and Respect;
- a generated load fixture with 200 members, 1,000 requests, 600 groups and
  2,000 bank item rows;
- LibSerialize/LibDeflate round trips and embedded license files.

Install `requirements.txt` into `tools/test-deps`, then run:

```powershell
python tests\run_checks.py
```

