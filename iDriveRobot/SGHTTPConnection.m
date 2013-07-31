#import "SGHTTPConnection.h"
#import "HTTPDataResponse.h"
#import "HTTPLogging.h"

#import "SGVideoResponse.h"

// Log levels: off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;


@implementation SGHTTPConnection

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
	// Use HTTPConnection's filePathForURI method.
	// This method takes the given path (which comes directly from the HTTP request),
	// and converts it to a full path by combining it with the configured document root.
	// 
	// It also does cool things for us like support for converting "/" to "/index.html",
	// and security restrictions (ensuring we don't serve documents outside configured document root folder).
	
	NSString *filePath = [self filePathForURI:path];
	
	// Convert to relative path
	
	NSString *documentRoot = [config documentRoot];
	
	if (![filePath hasPrefix:documentRoot]) {
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
	
	if ([relativePath hasPrefix:@"/livefeed"]) {
		HTTPLogVerbose(@"%@[%p]: Serving up dynamic content", THIS_FILE, self);
        
        return [[SGVideoResponse alloc] initWithConnection:self];
//        SGSource *src = [SGSource sharedSource];
//        NSData *data = [NSData dataWithBytesNoCopy:[src bytes] length:[src length]];
//        HTTPDataResponse *response = [[HTTPDataResponse alloc] initWithData:data];
//        response.httpHeaders = @{@"Content-Type" : @"video/raw"};
//        return response;
	}
	
	return [super httpResponseForMethod:method URI:path];
}

@end
