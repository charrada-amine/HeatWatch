// Reads Apple Silicon temperature sensors through the private IOHIDEventSystem API
// (same approach as Stats / macmon). Works without root.
#include "CSensors.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEvent *IOHIDEventRef;

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
extern IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef key);
extern double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define kIOHIDEventTypeTemperature 15
#define IOHIDEventFieldBase(type) ((type) << 16)

static IOHIDEventSystemClientRef shared_client(void) {
    static IOHIDEventSystemClientRef client = NULL;
    if (client) return client;
    client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return NULL;
    int page = 0xff00, usage = 5; // Apple vendor page, temperature sensors
    CFNumberRef nPage = CFNumberCreate(NULL, kCFNumberIntType, &page);
    CFNumberRef nUsage = CFNumberCreate(NULL, kCFNumberIntType, &usage);
    const void *keys[] = { CFSTR("PrimaryUsagePage"), CFSTR("PrimaryUsage") };
    const void *vals[] = { nPage, nUsage };
    CFDictionaryRef match = CFDictionaryCreate(NULL, keys, vals, 2,
        &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDEventSystemClientSetMatching(client, match);
    CFRelease(match);
    CFRelease(nPage);
    CFRelease(nUsage);
    return client;
}

int hw_read_temperatures(hw_sensor_reading *out, int max) {
    IOHIDEventSystemClientRef client = shared_client();
    if (!client) return 0;
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) return 0;
    int written = 0;
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex i = 0; i < count && written < max; i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (!event) continue;
        hw_sensor_reading *r = &out[written++];
        r->celsius = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
        CFRelease(event);
        r->name[0] = '\0';
        CFTypeRef name = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (name) {
            if (CFGetTypeID(name) == CFStringGetTypeID())
                CFStringGetCString((CFStringRef)name, r->name, sizeof(r->name), kCFStringEncodingUTF8);
            CFRelease(name);
        }
    }
    CFRelease(services);
    return written;
}
