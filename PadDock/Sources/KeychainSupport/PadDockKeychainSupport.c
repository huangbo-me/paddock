#include "PadDockKeychainSupport.h"
#include <pthread.h>

// Existing beta records live in the macOS file-based login keychain. LAContext
// alone does not suppress its legacy ACL dialogs. Scope and restore this process
// setting for every call, without changing any keychain item or access policy.
static pthread_mutex_t interactionLock = PTHREAD_MUTEX_INITIALIZER;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static OSStatus perform(int operation, CFDictionaryRef query, CFDictionaryRef attributes,
                        CFTypeRef *result, Boolean allowed) {
    pthread_mutex_lock(&interactionLock);
    Boolean previous = true;
    OSStatus status = SecKeychainGetUserInteractionAllowed(&previous);
    if (status == errSecSuccess) {
        status = SecKeychainSetUserInteractionAllowed(allowed);
        if (status == errSecSuccess) {
            if (operation == 0) status = SecItemCopyMatching(query, result);
            else if (operation == 1) status = SecItemUpdate(query, attributes);
            else status = SecItemAdd(query, NULL);
            OSStatus restored = SecKeychainSetUserInteractionAllowed(previous);
            if (status == errSecSuccess && restored != errSecSuccess) status = restored;
        }
    }
    pthread_mutex_unlock(&interactionLock);
    return status;
}
#pragma clang diagnostic pop
OSStatus PDKeychainRead(CFDictionaryRef query, CFTypeRef *result, Boolean allowed) {
    return perform(0, query, NULL, result, allowed);
}
OSStatus PDKeychainUpdate(CFDictionaryRef query, CFDictionaryRef attributes, Boolean allowed) {
    return perform(1, query, attributes, NULL, allowed);
}
OSStatus PDKeychainAdd(CFDictionaryRef attributes, Boolean allowed) {
    return perform(2, attributes, NULL, NULL, allowed);
}
