/**
 * HClash 原生内核桥接（NAPI shim）。
 *
 * 该 so 名为 libhclash_core.so，链接 Rust 静态库 libhclash_core_rust.a
 * （见 core/ 目录，内嵌 clash-rs 内核）。导出三个方法：
 *   start(configPath, homeDir, tunFd, apiPort, logLevel) -> number
 *   stop() -> void
 *   version() -> string
 */

#include <napi/native_api.h>
#include <string>
#include <vector>

extern "C" {
// core/src/lib.rs 导出的 C ABI
int32_t hclash_start(const char *config_path, const char *home_dir, int32_t tun_fd,
                     int32_t api_port, const char *log_level);
void hclash_stop(void);
const char *hclash_version(void);
void hclash_free_string(char *s);
}

namespace {

constexpr size_t MAX_STR = 4096;

bool GetUtf8(napi_env env, napi_value value, std::string &out) {
    size_t len = 0;
    napi_status status = napi_get_value_string_utf8(env, value, nullptr, 0, &len);
    if (status != napi_ok) {
        return false;
    }
    std::vector<char> buf(len + 1, 0);
    size_t copied = 0;
    status = napi_get_value_string_utf8(env, value, buf.data(), buf.size(), &copied);
    if (status != napi_ok) {
        return false;
    }
    out.assign(buf.data(), copied);
    return true;
}

napi_value Start(napi_env env, napi_callback_info info) {
    size_t argc = 5;
    napi_value argv[5] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
    if (argc < 5) {
        napi_value err = nullptr;
        napi_throw_error(env, nullptr, "start expects 5 arguments");
        napi_get_undefined(env, &err);
        return err;
    }

    std::string configPath;
    std::string homeDir;
    std::string logLevel;
    if (!GetUtf8(env, argv[0], configPath) || !GetUtf8(env, argv[1], homeDir)) {
        napi_throw_type_error(env, nullptr, "configPath/homeDir must be strings");
        napi_value ret = nullptr;
        napi_get_undefined(env, &ret);
        return ret;
    }
    int32_t tunFd = -1;
    int32_t apiPort = 9090;
    napi_get_value_int32(env, argv[2], &tunFd);
    napi_get_value_int32(env, argv[3], &apiPort);
    if (!GetUtf8(env, argv[4], logLevel)) {
        logLevel = "info";
    }

    int32_t rc = hclash_start(configPath.c_str(), homeDir.c_str(), tunFd, apiPort, logLevel.c_str());

    napi_value result = nullptr;
    napi_create_int32(env, rc, &result);
    return result;
}

napi_value Stop(napi_env env, napi_callback_info info) {
    (void)info;
    hclash_stop();
    napi_value result = nullptr;
    napi_get_undefined(env, &result);
    return result;
}

napi_value Version(napi_env env, napi_callback_info info) {
    (void)info;
    const char *ver = hclash_version();
    napi_value result = nullptr;
    napi_create_string_utf8(env, ver != nullptr ? ver : "", NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value Init(napi_env env, napi_value exports) {
    const napi_property_descriptor desc[] = {
        {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stop", nullptr, Stop, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

} // namespace

NAPI_MODULE(hclash_core, Init)
