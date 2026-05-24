-- ============================================================
-- TimescaleDB + PostGIS 扩展初始化
-- 此文件在 PostgreSQL 容器首次启动时自动执行
-- 文件名前缀 00_ 确保在 01_init_schemas.sql 之前执行
-- ============================================================

-- TimescaleDB 扩展（必须最先加载）
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- PostGIS 扩展
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- 确认扩展版本
DO $$
BEGIN
    RAISE NOTICE 'TimescaleDB version: %', (SELECT installed_version FROM pg_available_extensions WHERE name = 'timescaledb');
    RAISE NOTICE 'PostGIS version: %', (SELECT PostGIS_Version());
END $$;
