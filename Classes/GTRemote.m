//
//  GTRemote.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 9/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GTRemote.h"
#import "GTRepository.h"
#import "GTSignature.h"

static int rugged__push_status_cb(const char *ref, const char *msg, void *payload)
{
	//VALUE rb_result_hash = (VALUE)payload;
	//if (msg != NULL)
	//	rb_hash_aset(rb_result_hash, rb_str_new_utf8(ref), rb_str_new_utf8(msg));
	//NSLog(@"");
	return GIT_OK;
}

#import "NSError+Git.h"
#import "NSArray+StringArray.h"
#import "EXTScope.h"

@interface GTRemote ()

@property (nonatomic, readonly, assign) git_remote *git_remote;

@end

@implementation GTRemote

#pragma mark Lifecycle

- (id)initWithGitRemote:(git_remote *)remote {
	NSParameterAssert(remote != NULL);

	self = [super init];
	if (self == nil) return nil;

	_git_remote = remote;

	return self;
}

- (void)dealloc {
	if (_git_remote != NULL) git_remote_free(_git_remote);
}

#pragma mark NSObject

- (BOOL)isEqual:(GTRemote *)object {
	if (object == self) return YES;
	if (![object isKindOfClass:[self class]]) return NO;

	return [object.name isEqual:self.name] && [object.URLString isEqual:self.URLString];
}

- (NSUInteger)hash {
	return self.name.hash ^ self.URLString.hash;
}


+ (NSMutableDictionary *)loadRemote:(GTRepository *)repo url:(NSString *)repUrl signa:(GTSignature *)signa {
	
	NSMutableDictionary *response = [NSMutableDictionary dictionary];
	const git_signature *sign = [signa git_signature];
	git_remote *remote = NULL;
	int error = 0;

	if (git_remote_load(&remote, repo.git_repository, "github-mixture") == 0) {
		NSLog(@"loading remote");
		//git_remote_remove_refspec(<#git_remote *remote#>, <#size_t n#>)
	}
	else{
		error = git_remote_create(&remote,repo.git_repository, "github-mixture", [repUrl UTF8String]);
	}
		
	
	
	if(error){
		
		git_remote_free(remote);
		response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot create remote" forKey:@"Error"];
	}
	else{
	
		error = git_remote_connect(remote, GIT_DIRECTION_PUSH);
		if(error){
			
			git_remote_free(remote);
			response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot connect to remote" forKey:@"Error"];
		}
		else{
		
			git_push *gitPush = NULL;
			
			
			
			
			error = git_push_new(&gitPush, remote);
			if(error){
				git_push_free(gitPush);
				git_remote_free(remote);
				response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot push to remote" forKey:@"Error"];
			}
			else{
				error = git_push_add_refspec(gitPush, "+refs/heads/gh-pages");
				if(error){
					git_push_free(gitPush);
					git_remote_free(remote);
					response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot add refspec" forKey:@"Error"];
				}
				else{
					error = git_push_finish(gitPush);
					if(error){
						git_push_free(gitPush);
						git_remote_free(remote);
						response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot finish push" forKey:@"Error"];
					}
					else{
						if(!git_push_unpack_ok(gitPush)){
							
							git_push_free(gitPush);
							git_remote_free(remote);
							response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github" forKey:@"Error"];
						}
						else{
							void *payload = NULL;
							error = git_push_status_foreach(gitPush, &rugged__push_status_cb, (void *)payload);
														if(error){
															git_push_free(gitPush);
															git_remote_free(remote);
															response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github" forKey:@"Error"];
														}
														else{
							error = git_push_update_tips(gitPush, sign, NULL);
														}
							if(error){
								response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot update tips" forKey:@"Error"];
							}
							git_push_free(gitPush);
							git_remote_free(remote);
							
						}
					}
					
				}
				
			
			}
		}
	}
	return response;
	
	
}



#pragma mark API
/*
- (id)initWithGitRemote:(git_remote *)remote {
	self = [super init];
	if (self == nil) return nil;

	_git_remote = remote;

	return self;
}*/

#pragma mark Properties


- (NSString *)name {
	const char *name = git_remote_name(self.git_remote);
	if (name == NULL) return nil;

	return @(name);
}

- (NSString *)URLString {
	const char *URLString = git_remote_url(self.git_remote);
	if (URLString == NULL) return nil;

	return @(URLString);
}

- (NSArray *)fetchRefspecs {
	__block git_strarray refspecs;
	int gitError = git_remote_get_fetch_refspecs(&refspecs, self.git_remote);
	if (gitError != GIT_OK) return nil;

	@onExit {
		git_strarray_free(&refspecs);
	};

	return [NSArray git_arrayWithStrarray:refspecs];

}

#pragma mark Update the remote

- (BOOL)saveRemote:(NSError **)error {
	int gitError = git_remote_save(self.git_remote);
	if (gitError != GIT_OK) {
		if (error != NULL) {
			*error = [NSError git_errorFor:gitError description:@"Failed to save remote configuration."];
		}
		return NO;
	}
	return YES;
}

- (BOOL)updateURLString:(NSString *)URLString error:(NSError **)error {
	NSParameterAssert(URLString != nil);

	if ([self.URLString isEqualToString:URLString]) return YES;

	int gitError = git_remote_set_url(self.git_remote, URLString.UTF8String);
	if (gitError != GIT_OK) {
		if (error != NULL) {
			*error = [NSError git_errorFor:gitError description:@"Failed to update remote URL string."];
		}
		return NO;
	}
	return [self saveRemote:error];
}

- (BOOL)addFetchRefspec:(NSString *)fetchRefspec error:(NSError **)error {
	NSParameterAssert(fetchRefspec != nil);

	if ([self.fetchRefspecs containsObject:fetchRefspec]) return YES;

	int gitError = git_remote_add_fetch(self.git_remote, fetchRefspec.UTF8String);
	if (gitError != GIT_OK) {
		if (error != NULL) {
			*error = [NSError git_errorFor:gitError description:@"Failed to add fetch refspec."];
		}
		return NO;
	}
	return [self saveRemote:error];
}

@end
