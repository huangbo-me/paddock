#pragma once
#include <Security/Security.h>
OSStatus PDKeychainRead(CFDictionaryRef query, CFTypeRef *result, Boolean interactionAllowed);
OSStatus PDKeychainUpdate(CFDictionaryRef query, CFDictionaryRef attributes, Boolean interactionAllowed);
OSStatus PDKeychainAdd(CFDictionaryRef attributes, Boolean interactionAllowed);
