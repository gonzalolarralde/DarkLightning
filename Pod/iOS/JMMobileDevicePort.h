/**
 *  JMMobileDevicePort.h
 * 	DarkLightning
 *
 *
 *
 *	The MIT License (MIT)
 *
 *	Copyright (c) 2015 Jens Meder
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy of
 *	this software and associated documentation files (the "Software"), to deal in
 *	the Software without restriction, including without limitation the rights to
 *	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 *	the Software, and to permit persons to whom the Software is furnished to do so,
 *	subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in all
 *	copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 *	FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 *	COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 *	IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 *	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, JMMobileDevicePortState)
{
	JMMobileDevicePortStateIdle = 0,
	JMMobileDevicePortStateWaitingForConnection,
	JMMobileDevicePortStateConnected
};

@class JMMobileDevicePort;

@protocol JMMobileDevicePortDelegate <NSObject>

@optional

/**
 *  Called when data has been received via USB.
 *
 *  @param port The port that has received the data
 *  @param data   The received data
 */
-(void) mobileDevicePort:(nonnull JMMobileDevicePort*)port didReceiveData:(nonnull NSData*)data;

/**
 *  Called when the port after the port has changed its internal state.
 *
 *  @param port The port that has changed its state
 *  @param state  The new state of the port
 */
-(void) mobileDevicePort:(nonnull JMMobileDevicePort *)port didChangeState:(JMMobileDevicePortState)state;

@end

@interface JMMobileDevicePort : NSObject

/**
 *  The port the iOS device will be listening on
 */
@property (nonatomic, assign, readonly) uint32_t port;
@property (nullable, nonatomic, weak) id<JMMobileDevicePortDelegate> delegate;

/**
 *  The current state of the device port.
 */
@property (readonly) JMMobileDevicePortState state;

/**
 *  Creates and returns a new socket port for the given port.
 *
 *  @param port The port to listen on
 *
 *  @return A new socket port object
 */
-(nullable instancetype)initWithPort:(uint32_t)port;

/**
 *  Starts the port and listens for incoming connections via USB.
 */
-(void) open;

/**
 *  Stops the port and terminates any connections.
 */
-(void) close;

/**
 *  Writes data to a to the port if it is connected.
 *
 *  @param data The data to be sent
 */
-(BOOL) writeData:(nonnull NSData*)data;

@end
