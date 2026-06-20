# Phase 13D Source Package Hygiene

This project includes source/package hygiene tools.

Create a clean shareable zip:

``powershell
cd D:\BDS-Mobile\bds_commerce_flutter_starter
powershell -ExecutionPolicy Bypass -File .\tool\phase13d_make_clean_zip.ps1 -ProjectRoot "D:\BDS-Mobile\bds_commerce_flutter_starter" -OutputPath "D:\BDS-Mobile\releases\flutter_clean_source.zip"
powershell -ExecutionPolicy Bypass -File .\tool\phase13d_source_audit.ps1 -ZipPath "D:\BDS-Mobile\releases\flutter_clean_source.zip"
``

Live tree audit can show CHECK_REQUIRED if local logs/build artifacts exist. Clean release zip audit should be OK.
