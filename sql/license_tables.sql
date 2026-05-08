-- ============================================================
-- EyesOnCar 授权系统表结构
-- 所有表位于 lucky schema（项目默认 search_path）
-- ============================================================

-- 授权记录表
CREATE TABLE IF NOT EXISTS lucky.la_license (
    id          BIGSERIAL       PRIMARY KEY,
    machine_id  VARCHAR(32)     NOT NULL,
    license_raw TEXT            NOT NULL,
    add_devices INTEGER         NOT NULL,
    device_types JSONB          DEFAULT '[]'::jsonb,
    issued_at   TIMESTAMPTZ     NOT NULL,
    is_active   BOOLEAN         DEFAULT TRUE,
    imported_at TIMESTAMPTZ     DEFAULT NOW(),
    imported_by BIGINT
);

COMMENT ON TABLE  lucky.la_license              IS '授权记录表';
COMMENT ON COLUMN lucky.la_license.machine_id   IS '机器码(32位hex)';
COMMENT ON COLUMN lucky.la_license.license_raw  IS 'License原文(Base64)';
COMMENT ON COLUMN lucky.la_license.add_devices  IS '追加设备额度';
COMMENT ON COLUMN lucky.la_license.device_types IS '设备类型列表(空=通用)';
COMMENT ON COLUMN lucky.la_license.issued_at    IS '签发时间';
COMMENT ON COLUMN lucky.la_license.is_active    IS '是否有效';
COMMENT ON COLUMN lucky.la_license.imported_at  IS '导入时间';
COMMENT ON COLUMN lucky.la_license.imported_by  IS '导入操作人ID';


-- 设备绑定签名流水表
CREATE TABLE IF NOT EXISTS lucky.la_device_bindlog (
    id               BIGSERIAL       PRIMARY KEY,
    device_unique_id VARCHAR(64)     NOT NULL,
    device_type      VARCHAR(20)     NOT NULL,
    prev_unique_id   VARCHAR(64),
    modify_count     INTEGER         DEFAULT 0,
    bind_action      VARCHAR(20)     NOT NULL,
    bind_hash        VARCHAR(64)     NOT NULL,
    license_id       BIGINT          REFERENCES lucky.la_license(id),
    created_at       TIMESTAMPTZ     DEFAULT NOW(),
    operator_id      BIGINT
);

COMMENT ON TABLE  lucky.la_device_bindlog                   IS '设备绑定签名流水表';
COMMENT ON COLUMN lucky.la_device_bindlog.device_unique_id  IS '设备唯一编号(IMEI)';
COMMENT ON COLUMN lucky.la_device_bindlog.device_type       IS '设备类型: gps/digital_key';
COMMENT ON COLUMN lucky.la_device_bindlog.prev_unique_id    IS '修改前唯一编号';
COMMENT ON COLUMN lucky.la_device_bindlog.modify_count      IS '串号修改次数';
COMMENT ON COLUMN lucky.la_device_bindlog.bind_action       IS '操作类型: bind/unbind/modify';
COMMENT ON COLUMN lucky.la_device_bindlog.bind_hash         IS 'HMAC-SHA256签名';
COMMENT ON COLUMN lucky.la_device_bindlog.license_id        IS '关联License ID';
COMMENT ON COLUMN lucky.la_device_bindlog.created_at        IS '创建时间';
COMMENT ON COLUMN lucky.la_device_bindlog.operator_id       IS '操作人ID';

-- 索引
CREATE INDEX IF NOT EXISTS idx_bindlog_device ON lucky.la_device_bindlog(device_unique_id);
CREATE INDEX IF NOT EXISTS idx_bindlog_action ON lucky.la_device_bindlog(bind_action);
