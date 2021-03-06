//
//  JMUSBChannel.m
//  DarkLightning
//
//  Created by Jens Meder on 18/09/15.
//
//

#import "JMUSBChannel.h"
#import <netinet/in.h>
#import <sys/socket.h>
#import <sys/ioctl.h>
#import <sys/un.h>
#import <err.h>
#import "usbmux_packet.h"

static NSUInteger JMUSBChannelBufferSize = 2048;
static const char* JMUSBChannelUSBMUXDServicePath = "/var/run/usbmuxd";

@interface JMUSBChannel () <NSStreamDelegate>

@end

@implementation JMUSBChannel
{
	@private
	
	dispatch_fd_t 		_socketHandle;
	
	NSInputStream* 		_inputStream;
	NSOutputStream* 	_outputStream;
}

- (void)open
{	
	// Create socket

	_socketHandle = socket(AF_UNIX, SOCK_STREAM, 0);
	if (_socketHandle == -1)
	{
		if([_delegate respondsToSelector:@selector(channel:didFailToOpen:)])
		{
            NSError* error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                        code:errno
                                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]}];
			[_delegate channel:self didFailToOpen:error];
		}

		return;
	}
	
	[self setConnectionState:JMUSBChannelStateConnecting];
	
	// Prevent SIGPIPE

	int on = 1;
	setsockopt(_socketHandle, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
	
	// Connect socket

	struct sockaddr_un addr;
	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	strcpy(addr.sun_path, JMUSBChannelUSBMUXDServicePath);
	socklen_t socklen = sizeof(addr);
	
	if (connect(_socketHandle, (struct sockaddr*)&addr, socklen) == -1)
	{
		if([_delegate respondsToSelector:@selector(channel:didFailToOpen:)])
		{
            NSError* error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain
                                                        code:errno
                                                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:strerror(errno)]}];
			[_delegate channel:self didFailToOpen:error];
		}

		[self setConnectionState:JMUSBChannelStateDisconnected];

		return;
	}
	
	[self setupStreams];
	
	return;
}

-(void) setupStreams
{
	CFReadStreamRef readStream;
	CFWriteStreamRef writeStream;
	
	CFStreamCreatePairWithSocket(kCFAllocatorDefault, _socketHandle, &readStream, &writeStream);
	
	_inputStream = (__bridge NSInputStream *)(readStream);
	_outputStream = (__bridge NSOutputStream *)(writeStream);
	
	CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
	
	[_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	[_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	
	[_inputStream open];
	[_outputStream open];
}

-(BOOL)writeData:(NSData *)data
{
	if (_connectionState != JMUSBChannelStateConnected)
	{
		return NO;
	}

	NSInteger bytesWritten = [_outputStream write:data.bytes maxLength:data.length];

	if(bytesWritten > 0)
	{
		return YES;
	}

	return NO;
}

-(void)close
{
	_inputStream.delegate = self;
	_outputStream.delegate = self;
	
	[_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	[_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
	
	[_inputStream close];
	[_outputStream close];
	
	_inputStream = nil;
	_outputStream = nil;
	
	[self setConnectionState:JMUSBChannelStateDisconnected];
}

-(void) setConnectionState:(JMUSBChannelState)connectionState
{
	if (_connectionState == connectionState)
	{
		return;
	}
	
	_connectionState = connectionState;

	if([_delegate respondsToSelector:@selector(channel:didChangeState:)])
	{
		[_delegate channel:self didChangeState:_connectionState];
	}
}

#pragma mark - Stream Delegate

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
	if (eventCode == NSStreamEventHasSpaceAvailable && _inputStream.streamStatus == NSStreamStatusOpen && _outputStream.streamStatus == NSStreamStatusOpen)
	{
		[self setConnectionState:JMUSBChannelStateConnected];
	}
	else if(eventCode == NSStreamEventHasBytesAvailable)
	{
		NSMutableData* data = [NSMutableData data];
		uint8_t buffer[JMUSBChannelBufferSize];
		
		while (_inputStream.hasBytesAvailable)
		{
			NSInteger length = [_inputStream read:buffer maxLength:JMUSBChannelBufferSize];
			[data appendBytes:buffer length:length];
		}

		if ([_delegate respondsToSelector:@selector(channel:didReceiveData:)])
		{
			[_delegate channel:self didReceiveData:data];
		}
	}
	else if (eventCode == NSStreamEventEndEncountered)
	{
		[self setConnectionState:JMUSBChannelStateDisconnected];
	}
}

@end
