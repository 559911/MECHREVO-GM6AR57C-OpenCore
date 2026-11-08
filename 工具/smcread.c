// smcread - 直接读取 AppleSMC 键值，用于判断 VirtualSMC/SMCProcessor 是否发布了传感器键
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <IOKit/IOKitLib.h>

typedef struct { char major; char minor; char build; char reserved[1]; uint16_t release; } SMCKeyData_vers_t;
typedef struct { uint16_t version; uint16_t length; uint32_t cpuPLimit; uint32_t gpuPLimit; uint32_t memPLimit; } SMCKeyData_pLimitData_t;
typedef struct { uint32_t dataSize; uint32_t dataType; char dataAttributes; } SMCKeyData_keyInfo_t;

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData_t;

#define KERNEL_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_INDEX 8
#define SMC_CMD_READ_KEYINFO 9

static io_connect_t conn;

static uint32_t _strtoul(const char *str, int size, int base) {
    uint32_t total = 0;
    for (int i = 0; i < size; i++) {
        if (base == 16) total += (uint32_t)str[i] << (size - 1 - i) * 8;
        else total += (unsigned char)str[i] << (size - 1 - i) * 8;
    }
    return total;
}

static kern_return_t SMCCall(int index, SMCKeyData_t *in, SMCKeyData_t *out) {
    size_t outSize = sizeof(SMCKeyData_t);
    return IOConnectCallStructMethod(conn, index, in, sizeof(SMCKeyData_t), out, &outSize);
}

static kern_return_t SMCReadKeyInfo(uint32_t key, SMCKeyData_keyInfo_t *ki) {
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in)); memset(&out, 0, sizeof(out));
    in.key = key; in.data8 = SMC_CMD_READ_KEYINFO;
    kern_return_t r = SMCCall(KERNEL_INDEX_SMC, &in, &out);
    if (r != kIOReturnSuccess) return r;
    *ki = out.keyInfo;
    return kIOReturnSuccess;
}

static kern_return_t SMCReadKey(uint32_t key, uint8_t *buf, uint32_t *size, uint32_t *type) {
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in)); memset(&out, 0, sizeof(out));
    in.key = key; in.data8 = SMC_CMD_READ_KEYINFO;
    kern_return_t r = SMCCall(KERNEL_INDEX_SMC, &in, &out);
    if (r != kIOReturnSuccess) return r;
    uint32_t ds = out.keyInfo.dataSize;
    uint32_t dt = out.keyInfo.dataType;
    if (ds == 0 || ds > 32) { *size = 0; *type = dt; return kIOReturnError; }
    memset(&in, 0, sizeof(in)); memset(&out, 0, sizeof(out));
    in.key = key; in.keyInfo.dataSize = ds; in.data8 = SMC_CMD_READ_BYTES;
    r = SMCCall(KERNEL_INDEX_SMC, &in, &out);
    if (r != kIOReturnSuccess) return r;
    memcpy(buf, out.bytes, ds);
    *size = ds; *type = dt;
    return kIOReturnSuccess;
}

static double decode(const uint8_t *b, uint32_t size, uint32_t type) {
    if (size == 0) return -1;
    if (type == _strtoul("sp78", 4, 16) && size >= 2) {
        return (int16_t)((b[0] << 8) | b[1]) / 256.0;
    }
    if (type == _strtoul("fpe2", 4, 16) && size >= 2) {
        return ((b[0] << 8) | b[1]) / 4.0;
    }
    if (type == _strtoul("flt ", 4, 16) && size >= 4) {
        float f; memcpy(&f, b, 4); return f;
    }
    if (type == _strtoul("ui16", 4, 16) && size >= 2) {
        return (b[0] << 8) | b[1];
    }
    if (type == _strtoul("ui8 ", 4, 16) && size >= 1) {
        return b[0];
    }
    if (type == _strtoul("sp96", 4, 16) && size >= 2) {
        return (int16_t)((b[0] << 8) | b[1]) / 64.0;
    }
    if (type == _strtoul("sp3c", 4, 16) && size >= 2) {
        return (int16_t)((b[0] << 8) | b[1]) / 4096.0;
    }
    if (type == _strtoul("fp88", 4, 16) && size >= 2) {
        return (b[0] << 8 | b[1]) / 256.0;
    }
    return -1;
}

int main(int argc, char **argv) {
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!svc) { printf("AppleSMC 服务不存在\n"); return 1; }
    kern_return_t r = IOServiceOpen(svc, mach_task_self(), 0, &conn);
    if (r != kIOReturnSuccess) { printf("IOServiceOpen 失败: 0x%x\n", r); return 1; }

    // 总键数
    uint8_t buf[32]; uint32_t size = 0, type = 0;
    if (SMCReadKey(_strtoul("#KEY", 4, 16), buf, &size, &type) == kIOReturnSuccess && size == 4) {
        uint32_t n = (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | buf[3];
        printf("SMC 键总数: %u\n", n);
    } else {
        printf("读 #KEY 失败\n");
    }

    if (argc > 1 && strcmp(argv[1], "dump") == 0) {
        uint32_t n = 0;
        if (SMCReadKey(_strtoul("#KEY", 4, 16), buf, &size, &type) == kIOReturnSuccess && size == 4)
            n = (buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | buf[3];
        for (uint32_t i = 0; i < n; i++) {
            SMCKeyData_t in, out;
            memset(&in, 0, sizeof(in)); memset(&out, 0, sizeof(out));
            in.data8 = SMC_CMD_READ_INDEX; in.data32 = i;
            if (SMCCall(KERNEL_INDEX_SMC, &in, &out) != kIOReturnSuccess) continue;
            char k[5] = { (char)(out.key >> 24), (char)(out.key >> 16), (char)(out.key >> 8), (char)out.key, 0 };
            printf("%s ", k);
        }
        printf("\n");
        return 0;
    }

    if (argc > 1 && strcmp(argv[1], "k") == 0) {
        for (int a = 2; a < argc; a++) {
            uint32_t k = _strtoul(argv[a], 4, 16);
            SMCKeyData_keyInfo_t ki;
            if (SMCReadKeyInfo(k, &ki) != kIOReturnSuccess || ki.dataSize == 0) {
                printf("%-6s 不存在\n", argv[a]); continue;
            }
            char t[5] = { (char)(ki.dataType >> 24), (char)(ki.dataType >> 16), (char)(ki.dataType >> 8), (char)ki.dataType, 0 };
            if (SMCReadKey(k, buf, &size, &type) != kIOReturnSuccess) { printf("%-6s 读取失败\n", argv[a]); continue; }
            printf("%-6s %-6s len=%u raw=%02x%02x val=%.3f\n", argv[a], t, size, buf[0], buf[1], decode(buf, size, type));
        }
        return 0;
    }

    const char *keys[] = {
        "TC0P","TC0D","TC0E","TC0F","TC0J","TC0H","TC0C","TC1C","TC2C","TC3C","TC4C","TC5C","TC6C","TC7C",
        "TC8C","TC9C","TCAC","TCBC","TCCC","TCDC","TCEC","TCFC","TG0P","TG0D","TG0H",
        "TA0P","TB0T","Ts0P","TM0P","TH0P","TP0P","Tp09","Tp0T",
        "F0Ac","F0Mn","F0Mx","F0ID","F1Ac",
        "PCPT","PC0C","VC0C","VP0R",
        NULL
    };
    printf("%-6s %-8s %-6s %s\n", "键", "类型", "长度", "值");
    for (int i = 0; keys[i]; i++) {
        uint32_t k = _strtoul(keys[i], 4, 16);
        SMCKeyData_keyInfo_t ki;
        if (SMCReadKeyInfo(k, &ki) != kIOReturnSuccess || ki.dataSize == 0) {
            printf("%-6s %-8s %-6s %s\n", keys[i], "-", "0", "不存在");
            continue;
        }
        char t[5] = { (char)(ki.dataType >> 24), (char)(ki.dataType >> 16), (char)(ki.dataType >> 8), (char)ki.dataType, 0 };
        if (SMCReadKey(k, buf, &size, &type) != kIOReturnSuccess) {
            printf("%-6s %-8s %-6u %s\n", keys[i], t, ki.dataSize, "读取失败");
            continue;
        }
        double v = decode(buf, size, type);
        if (v >= 0) printf("%-6s %-8s %-6u %.2f\n", keys[i], t, ki.dataSize, v);
        else printf("%-6s %-8s %-6u (原始 %02x %02x)\n", keys[i], t, ki.dataSize, buf[0], buf[1]);
    }
    IOServiceClose(conn);
    return 0;
}
