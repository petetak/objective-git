//
//  NSData+Git.m
//

#import "NSData+Git.h"
#import "NSError+Git.h"

@implementation NSData (Git)

+ (NSData *)git_dataWithOid:(git_oid *)oid {
    return [NSData dataWithBytes:oid length:sizeof(git_oid)];
}

- (BOOL)git_getOid:(git_oid *)oid error:(NSError **)error {
    if ([self length] != sizeof(git_oid)) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:GTGitErrorDomain 
                                         code:GITERR_INVALID 
                                     userInfo:
                      [NSDictionary dictionaryWithObject:@"can't extract oid from data of incorrect length" 
                                                  forKey:NSLocalizedDescriptionKey]];
        }
        return NO;
    }
    
    [self getBytes:oid length:sizeof(git_oid)];
    return YES;
}

+ (instancetype)git_dataWithBuffer:(git_buf *)buffer {
	NSCParameterAssert(buffer != NULL);

	// Ensure that the buffer is actually allocated dynamically, not pointing to
	// some data which may disappear.
	if (git_buf_grow(buffer, 0) != GIT_OK) return nil;
	
	NSData *data = [self dataWithBytesNoCopy:buffer->ptr length:buffer->size freeWhenDone:YES];
	*buffer = (git_buf)GIT_BUF_INIT_CONST(0, NULL);

	return data;
}

- (git_buf)git_buf {
	return (git_buf)GIT_BUF_INIT_CONST((void *)self.bytes, self.length);
}

@end
