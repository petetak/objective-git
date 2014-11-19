//
//  GTRemote.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 9/12/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "GTRemote.h"
#import "GTRepository.h"
#import "GTOID.h"
#import "GTCredential+Private.h"
#import "GTBranch.h"


#import "GTSignature.h"

static int rugged__push_status_cb(const char *ref, const char *msg, void *payload)
{
	//VALUE rb_result_hash = (VALUE)payload;
	//if (msg != NULL)
	//	rb_hash_aset(rb_result_hash, rb_str_new_utf8(ref), rb_str_new_utf8(msg));
	//NSLog(@"");
	return GIT_OK;
}

const char * username;
const char * password;

int cred_acquire_cb(git_cred **out,
					const char * url,
					const char * username_from_url,
					unsigned int allowed_types,
					void * payload)
{
	return git_cred_userpass_plaintext_new(out, username, password);
}


#import "NSError+Git.h"
#import "NSArray+StringArray.h"
#import "EXTScope.h"

#import "git2/errors.h"

NSString * const GTRemoteRenameProblematicRefSpecs = @"GTRemoteRenameProblematicRefSpecs";

@interface GTRemote ()

@property (nonatomic, readonly, assign) git_remote *git_remote;
@end

@implementation GTRemote

#pragma mark Lifecycle

+ (NSMutableDictionary *)loadRemote:(GTRepository *)repo url:(NSString *)repUrl signa:(GTSignature *)signa username: (NSString *)user password: (NSString *)pass branch: (NSString *)branch  {
	
	username = user.UTF8String;
	password = pass.UTF8String;
	
	NSString *const CACertificateFile_DigiCert = @"DigiCert High Assurance EV Root CA.pem";
	NSString *const certFilePath = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:CACertificateFile_DigiCert];
	NSLog(@"Loading certificate: %@", certFilePath);
 
	const char *file = certFilePath.UTF8String;
	const char *path = NULL;
 
	int returnValue = git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, file, path);
	if (returnValue != 0) {
		NSLog(@"Error setting SSL certificate location");
	}
	
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
	
	
	
	//ensure we have remote branches locally
	//error = git_remote_fetch(remote, sign, NULL);
	//NSError *err;
	//GTRemote *rem = [[GTRemote alloc] initWithGitRemote:remote];
	//GTReference *headRef = [repo headReferenceWithError:&err];
	//GTBranch *br = [GTBranch branchWithReference:headRef repository:repo];
	//error = git_remote_add_push(remote, "+refs/heads/gh-pages");
	
	//br = [br reloadedBranchWithError:&err];
	//NSArray *pete = [rem fetchRefspecs];
	
	//NSLog(@"pete %@",pete);
	
	
	if(error){
		
		git_remote_free(remote);
		response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github - cannot create remote" forKey:@"Error"];
	}
	else{
		//git_cred *git_cred = NULL;
		git_remote_callbacks callbacks = GIT_REMOTE_CALLBACKS_INIT;
		callbacks.credentials = cred_acquire_cb;
		git_remote_set_callbacks(remote, &callbacks);
		
		error = git_remote_connect(remote, GIT_DIRECTION_PUSH);
		if(error < 0){
			const git_error *e = giterr_last();
			NSString *errorMessage = [NSString stringWithUTF8String:e->message];
			response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
			git_remote_free(remote);
		}
		else{
			
			
			/* All of the above in one step */
			/*error = git_remote_fetch(remote, sign, NULL);
			 if(error < 0){
				const git_error *e = giterr_last();
				NSString *errorMessage = [NSString stringWithUTF8String:e->message];
				response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
			 }*/
			
			git_push *gitPush = NULL;
			
			error = git_push_new(&gitPush, remote);
			if(error < 0){
				const git_error *e = giterr_last();
				NSString *errorMessage = [NSString stringWithUTF8String:e->message];
				response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
				git_push_free(gitPush);
				git_remote_free(remote);
				
			}
			else{
				
				
				NSString *refSpec = [NSString stringWithFormat: @"+refs/heads/%@:refs/heads/%@", branch, branch];
				//NSLog(@"refspec %@",refSpec);
				//git_strarray fetch_refspecs = {0};
				//error = git_remote_get_fetch_refspecs(&fetch_refspecs, remote);
				//git_strarray push_refspecs = {0};
				//error = git_remote_get_push_refspecs(&push_refspecs, remote);
				
				//fetch_refspecs = push_refspecs;
				
				/*error = git_remote_add_push(remote, "refs/remotes/github-mixture/dog");
				 if (error < 0) {
					const git_error *e = giterr_last();
					printf("Error 1 %d/%d: %s\n", error, e->klass, e->message);
					
				 }
				 git_strarray push_refspecs = {0};
				 error = git_remote_get_push_refspecs(&push_refspecs, remote);*/
				error = git_push_add_refspec(gitPush, [refSpec UTF8String]);
				if(error < 0){
					const git_error *e = giterr_last();
					NSString *errorMessage = [NSString stringWithUTF8String:e->message];
					response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
					
					git_push_free(gitPush);
					git_remote_free(remote);
					
				}
				else{
					error = git_push_finish(gitPush);
					if(error < 0){
						const git_error *e = giterr_last();
						NSString *errorMessage = [NSString stringWithUTF8String:e->message];
						response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
						git_push_free(gitPush);
						git_remote_free(remote);
						
					}
					else{
						if(!git_push_unpack_ok(gitPush)){
							/*if (error < 0) {
								const git_error *e = giterr_last();
								printf("Error %d/%d: %s\n", error, e->klass, e->message);
								
							 }*/
							git_push_free(gitPush);
							git_remote_free(remote);
							response = [NSMutableDictionary dictionaryWithObject:@"Error pushing to Github" forKey:@"Error"];
						}
						else{
							void *payload = NULL;
							error = git_push_status_foreach(gitPush, &rugged__push_status_cb, (void *)payload);
							if(error < 0){
								const git_error *e = giterr_last();
								NSString *errorMessage = [NSString stringWithUTF8String:e->message];
								response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
								git_push_free(gitPush);
								git_remote_free(remote);
								
							}
							else{
								error = git_push_update_tips(gitPush, sign, NULL);
								if(error < 0){
									const git_error *e = giterr_last();
									NSString *errorMessage = [NSString stringWithUTF8String:e->message];
									response = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Error pushing to Github: %@",errorMessage] forKey:@"Error"];
									git_push_free(gitPush);
									git_remote_free(remote);
								}
								else{
									//complete
									git_push_free(gitPush);
									git_remote_free(remote);
								}
							}
							
							
							
						}
					}
					
				}
				
				
			}
		}
	}
	return response;
	
	
}


+ (instancetype)createRemoteWithName:(NSString *)name URLString:(NSString *)URLString inRepository:(GTRepository *)repo error:(NSError **)error {
	NSParameterAssert(name != nil);
	NSParameterAssert(URLString != nil);
	NSParameterAssert(repo != nil);

	git_remote *remote;
	int gitError = git_remote_create(&remote, repo.git_repository, name.UTF8String, URLString.UTF8String);
	if (gitError != GIT_OK) {
		if (error != NULL) *error = [NSError git_errorFor:gitError description:@"Remote creation failed" failureReason:@"Failed to create a remote named \"%@\" for \"%@\"", name, URLString];

		return nil;
	}

	return [[self alloc] initWithGitRemote:remote inRepository:repo];
}

+ (instancetype)remoteWithName:(NSString *)name inRepository:(GTRepository *)repo error:(NSError **)error {
	NSParameterAssert(name != nil);
	NSParameterAssert(repo != nil);

	git_remote *remote;
	int gitError = git_remote_load(&remote, repo.git_repository, name.UTF8String);
	if (gitError != GIT_OK) {
		if (error != NULL) *error = [NSError git_errorFor:gitError description:@"Remote loading failed" failureReason:nil];

		return nil;
	}

	return [[self alloc] initWithGitRemote:remote inRepository:repo];
}

- (instancetype)initWithGitRemote:(git_remote *)remote inRepository:(GTRepository *)repo {
	NSParameterAssert(remote != NULL);
	NSParameterAssert(repo != nil);

	self = [super init];
	if (self == nil) return nil;

	_git_remote = remote;
	_repository = repo;

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

#pragma mark API

+ (BOOL)isSupportedURLString:(NSString *)URLString {
	NSParameterAssert(URLString != nil);

	return git_remote_supported_url(URLString.UTF8String) == GIT_OK;
}

+ (BOOL)isValidRemoteName:(NSString *)name {
	NSParameterAssert(name != nil);

	return git_remote_is_valid_name(name.UTF8String) == GIT_OK;
}

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

- (void)setURLString:(NSString *)URLString {
	git_remote_set_url(self.git_remote, URLString.UTF8String);
}

- (NSString *)pushURLString {
	const char *pushURLString = git_remote_pushurl(self.git_remote);
	if (pushURLString == NULL) return nil;

	return @(pushURLString);
}

- (void)setPushURLString:(NSString *)pushURLString {
	git_remote_set_pushurl(self.git_remote, pushURLString.UTF8String);
}

- (BOOL)updatesFetchHead {
	return git_remote_update_fetchhead(self.git_remote) != 0;
}

- (void)setUpdatesFetchHead:(BOOL)updatesFetchHead {
	git_remote_set_update_fetchhead(self.git_remote, updatesFetchHead);
}

- (GTRemoteAutoTagOption)autoTag {
	return (GTRemoteAutoTagOption)git_remote_autotag(self.git_remote);
}

- (void)setAutoTag:(GTRemoteAutoTagOption)autoTag {
	git_remote_set_autotag(self.git_remote, (git_remote_autotag_option_t)autoTag);
}

- (BOOL)isConnected {
	return git_remote_connected(self.git_remote) != 0;
}

#pragma mark Renaming

- (BOOL)rename:(NSString *)name error:(NSError **)error {
	NSParameterAssert(name != nil);
	
	git_strarray problematic_refspecs;
	
	int gitError = git_remote_rename(&problematic_refspecs, self.git_remote, name.UTF8String);
	if (gitError != GIT_OK) {
		NSArray *problematicRefspecs = [NSArray git_arrayWithStrarray:problematic_refspecs];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObject:problematicRefspecs forKey:GTRemoteRenameProblematicRefSpecs];

		if (error != NULL) *error = [NSError git_errorFor:gitError description:@"Failed to rename remote" userInfo:userInfo failureReason:@"Couldn't rename remote %@ to %@", self.name, name];
	}

	git_strarray_free(&problematic_refspecs);

	return gitError == GIT_OK;
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

- (NSArray *)pushRefspecs {
	__block git_strarray refspecs;
	int gitError = git_remote_get_push_refspecs(&refspecs, self.git_remote);
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
