-- ============================================================
-- 车联网平台 PostgreSQL 初始化脚本
-- 创建独立 schema，启用 PostGIS 扩展
-- ============================================================

-- 创建三个独立 schema
CREATE SCHEMA IF NOT EXISTS lucky;
CREATE SCHEMA IF NOT EXISTS geo;
CREATE SCHEMA IF NOT EXISTS traccar;

-- 启用 PostGIS 扩展（在 public schema 中创建，所有 schema 可用）
CREATE EXTENSION IF NOT EXISTS postgis;

-- 在 geo schema 中也确保 PostGIS 可用
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA geo;

-- 设置默认 search_path（不使用 public）
ALTER DATABASE iot_platform SET search_path TO lucky, geo, traccar;

-- 授权（确保 iot_admin 拥有所有 schema 的完整权限）
GRANT ALL ON SCHEMA lucky TO iot_admin;
GRANT ALL ON SCHEMA geo TO iot_admin;
GRANT ALL ON SCHEMA traccar TO iot_admin;
