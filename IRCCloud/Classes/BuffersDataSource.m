//
//  BuffersDataSource.m
//
//  Copyright (C) 2013 IRCCloud, Ltd.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


#import "BuffersDataSource.h"
#import "ChannelsDataSource.h"
#import "EventsDataSource.h"
#import "UsersDataSource.h"
#import "ServersDataSource.h"

@implementation Buffer
-(NSComparisonResult)compare:(Buffer *)aBuffer {
    int joinedLeft = 1, joinedRight = 1;
    if([_type isEqualToString:@"channel"])
        joinedLeft = [[ChannelsDataSource sharedInstance] channelForBuffer:_bid] != nil;
    if([[aBuffer type] isEqualToString:@"channel"])
        joinedRight = [[ChannelsDataSource sharedInstance] channelForBuffer:aBuffer.bid] != nil;
    if([_type isEqualToString:@"conversation"] && [[aBuffer type] isEqualToString:@"channel"])
        return NSOrderedDescending;
    else if([_type isEqualToString:@"channel"] && [[aBuffer type] isEqualToString:@"conversation"])
        return NSOrderedAscending;
    else if(joinedLeft > joinedRight)
        return NSOrderedAscending;
    else if(joinedLeft < joinedRight)
        return NSOrderedDescending;
    else {
        if(_chantypes == nil) {
            Server *s = [[ServersDataSource sharedInstance] getServer:_cid];
            if(s) {
                _chantypes = s.CHANTYPES;
                if(_chantypes == nil || _chantypes.length == 0)
                    _chantypes = @"#";
            }
        }
        NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^[%@]+", _chantypes] options:NSRegularExpressionCaseInsensitive error:nil];
        NSString *nameLeft = [r stringByReplacingMatchesInString:[_name lowercaseString] options:0 range:NSMakeRange(0, _name.length) withTemplate:@""];
        NSString *nameRight = [r stringByReplacingMatchesInString:[aBuffer.name lowercaseString] options:0 range:NSMakeRange(0, aBuffer.name.length) withTemplate:@""];
        return [nameLeft compare:nameRight];
    }
}
-(NSString *)description {
    return [NSString stringWithFormat:@"{cid: %i, bid: %i, name: %@, type: %@}", _cid, _bid, _name, _type];
}
-(NSString *)accessibilityValue {
    if(_chantypes == nil) {
        Server *s = [[ServersDataSource sharedInstance] getServer:_cid];
        if(s) {
            _chantypes = [s.isupport objectForKey:@"CHANTYPES"];
            if(_chantypes == nil || _chantypes.length == 0)
                _chantypes = @"#";
        }
    }
    NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"^[%@]+", _chantypes] options:NSRegularExpressionCaseInsensitive error:nil];
    return [r stringByReplacingMatchesInString:[_name lowercaseString] options:0 range:NSMakeRange(0, _name.length) withTemplate:@""];
}
@end

@implementation BuffersDataSource
+(BuffersDataSource *)sharedInstance {
    static BuffersDataSource *sharedInstance;
	
    @synchronized(self) {
        if(!sharedInstance)
            sharedInstance = [[BuffersDataSource alloc] init];
		
        return sharedInstance;
    }
	return nil;
}

-(id)init {
    self = [super init];
    _buffers = [[NSMutableDictionary alloc] init];
    return self;
}

-(void)clear {
    @synchronized(_buffers) {
        [_buffers removeAllObjects];
    }
}

-(NSUInteger)count {
    @synchronized(_buffers) {
        return _buffers.count;
    }
}

-(int)firstBid {
    @synchronized(_buffers) {
        if(_buffers.count)
            return ((Buffer *)[_buffers.allValues objectAtIndex:0]).bid;
        else
            return -1;
    }
}

-(void)addBuffer:(Buffer *)buffer {
    @synchronized(_buffers) {
        [_buffers setObject:buffer forKey:@(buffer.bid)];
    }
}

-(Buffer *)getBuffer:(int)bid {
    return [_buffers objectForKey:@(bid)];
}

-(Buffer *)getBufferWithName:(NSString *)name server:(int)cid {
    NSArray *copy;
    @synchronized(_buffers) {
        copy = _buffers.allValues;
    }
    for(Buffer *buffer in copy) {
        if(buffer.cid == cid && [[buffer.name lowercaseString] isEqualToString:[name lowercaseString]])
            return buffer;
    }
    return nil;
}

-(NSArray *)getBuffersForServer:(int)cid {
    NSMutableArray *buffers = [[NSMutableArray alloc] init];
    NSArray *copy;
    @synchronized(_buffers) {
        copy = _buffers.allValues;
    }
    for(Buffer *buffer in copy) {
        if(buffer.cid == cid)
            [buffers addObject:buffer];
    }
    return [buffers sortedArrayUsingSelector:@selector(compare:)];
}

-(NSArray *)getBuffers {
    @synchronized(_buffers) {
        return _buffers.allValues;
    }
}

-(void)updateLastSeenEID:(NSTimeInterval)eid buffer:(int)bid {
    Buffer *buffer = [self getBuffer:bid];
    if(buffer)
        buffer.last_seen_eid = eid;
}

-(void)updateArchived:(int)archived buffer:(int)bid {
    Buffer *buffer = [self getBuffer:bid];
    if(buffer)
        buffer.archived = archived;
}

-(void)updateTimeout:(int)timeout buffer:(int)bid {
    Buffer *buffer = [self getBuffer:bid];
    if(buffer)
        buffer.timeout = timeout;
}

-(void)updateName:(NSString *)name buffer:(int)bid {
    Buffer *buffer = [self getBuffer:bid];
    if(buffer)
        buffer.name = name;
}

-(void)updateAway:(NSString *)away nick:(NSString *)nick server:(int)cid {
    Buffer *buffer = [self getBufferWithName:nick server:cid];
    if(buffer)
        buffer.away_msg = away;
}

-(void)removeBuffer:(int)bid {
    @synchronized(_buffers) {
        NSArray *copy;
        @synchronized(_buffers) {
            copy = _buffers.allValues;
        }
        for(Buffer *buffer in copy) {
            if(buffer.lastBuffer.bid == bid)
                buffer.lastBuffer = buffer.lastBuffer.lastBuffer;
        }
        [_buffers removeObjectForKey:@(bid)];
    }
}

-(void)removeAllDataForBuffer:(int)bid {
    Buffer *buffer = [self getBuffer:bid];
    if(buffer) {
        [self removeBuffer:bid];
        [[ChannelsDataSource sharedInstance] removeChannelForBuffer:bid];
        [[EventsDataSource sharedInstance] removeEventsForBuffer:bid];
        [[UsersDataSource sharedInstance] removeUsersForBuffer:bid];
    }
}

-(void)invalidate {
    NSArray *copy;
    @synchronized(_buffers) {
        copy = _buffers.allValues;
    }
    for(Buffer *buffer in copy) {
        buffer.valid = NO;
    }
}

-(void)purgeInvalidBIDs {
    NSLog(@"Cleaning up invalid BIDs");
    NSArray *copy;
    @synchronized(_buffers) {
        copy = _buffers.allValues;
    }
    for(Buffer *buffer in copy) {
        if(!buffer.valid) {
            NSLog(@"Removing buffer: %@", buffer);
            [[ChannelsDataSource sharedInstance] removeChannelForBuffer:buffer.bid];
            [[EventsDataSource sharedInstance] removeEventsForBuffer:buffer.bid];
            [[UsersDataSource sharedInstance] removeUsersForBuffer:buffer.bid];
            if([buffer.type isEqualToString:@"console"]) {
                NSLog(@"Removing CID: %i", buffer.cid);
                [[ServersDataSource sharedInstance] removeServer:buffer.cid];
            }
            [self removeBuffer:buffer.bid];
        }
    }
}

-(void)finalize {
    NSLog(@"BuffersDataSource: HALP! I'm being garbage collected!");
}
@end
