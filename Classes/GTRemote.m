//
//  GTRemote.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 9/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GTRemote.h"
#import "GTRepository.h"

static int rugged__push_status_cb(const char *ref, const char *msg, void *payload)
{
	//VALUE rb_result_hash = (VALUE)payload;
	//if (msg != NULL)
	//	rb_hash_aset(rb_result_hash, rb_str_new_utf8(ref), rb_str_new_utf8(msg));
	//NSLog(@"");
	return GIT_OK;
}

@interface GTRemote ()
@property (nonatomic, readonly, assign) git_remote *git_remote;
@end

@implementation GTRemote

- (void)dealloc {
	if (_git_remote != NULL) git_remote_free(_git_remote);
}

- (BOOL)isEqual:(GTRemote *)object {
	if (object == self) return YES;
	if (![object isKindOfClass:[self class]]) return NO;

	return [object.name isEqual:self.name] && [object.URLString isEqual:self.URLString];
}

- (NSUInteger)hash {
	return self.name.hash ^ self.URLString.hash;
}

+ (NSMutableDictionary *)loadRemote:(GTRepository *)repository url:(NSString *)repoUrl{
	
	NSMutableDictionary *response = [NSMutableDictionary dictionary];
	
	git_remote *remote = NULL;
	int error = 0;

	if (git_remote_load(&remote, repository.git_repository, "github-mixture") == 0) {
		NSLog(@"loading remote");
		//git_remote_remove_refspec(<#git_remote *remote#>, <#size_t n#>)
	}
	else{
		error = git_remote_create(&remote,repository.git_repository, "github-mixture", [repoUrl UTF8String]);
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
							error = git_push_update_tips(gitPush);
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

- (id)initWithGitRemote:(git_remote *)remote {
	self = [super init];
	if (self == nil) return nil;

	_git_remote = remote;

	return self;
}

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

@end
