//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 6/22/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import "RegexParser.h"

static RegexParser* sharedInstance = nil;

@implementation RegexParser

+ (RegexParser *)sharedInstance  {
	@synchronized (self) {
		if (sharedInstance == nil) {
			[[self alloc] init]; // assignment not done here, see allocWithZone
		}
	}
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
	
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;  // This is sooo not zero
}

- (id)init {
    @synchronized(self) {
        self = [super init];
        if (self) {
            NSError *error = nil;
            NSString *filePath = [[NSBundle mainBundle] pathForResource:@"regex" ofType:@"json"];
            NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error: &error];
            
            if (jsonData) {
                
                NSDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error: &error];
                
                if (!jsonArray) {
                    @throw error;
                } else {
                    _vowel = [[NSString alloc] initWithString:[jsonArray objectForKey:@"vowel"]];
                    _consonant = [[NSString alloc] initWithString:[jsonArray objectForKey:@"consonant"]];
                    _casesensitive = [[NSString alloc] initWithString:[jsonArray objectForKey:@"casesensitive"]];
                    _patterns = [[NSArray alloc] initWithArray:[jsonArray objectForKey:@"patterns"]];
                    _maxPatternLength = [[[_patterns objectAtIndex:0] objectForKey:@"find"] length];
                }
                
            } else {
                @throw error;
            }
        }
        return self;
    }
}

- (void)dealloc {
    @synchronized(self) {
        [_vowel release];
        [_consonant release];
        [_casesensitive release];
        [_patterns release];
        
        [super dealloc];
    }
}

- (NSString*)parse:(NSString *)string {
    @synchronized(self) {
        if (!string || [string length] == 0) {
            return string;
        }
        
        NSString* fixed = [self clean:string];
        NSMutableString* output = [[NSMutableString alloc] initWithCapacity:0];
        
        int len = [fixed length], cur;
        for(cur = 0; cur < len; ++cur) {
            int start = cur, end;
            BOOL matched = FALSE;
            
            int chunkLen;
            for(chunkLen = _maxPatternLength; chunkLen > 0; --chunkLen) {
                end = start + chunkLen;
                if(end <= len) {
                    NSString* chunk = [fixed substringWithRange:NSMakeRange(start, chunkLen)];
                    
                    // Binary Search
                    int left = 0, right = [_patterns count] - 1, mid;
                    while(right >= left) {
                        mid = (right + left) / 2;
                        NSDictionary* pattern = [_patterns objectAtIndex:mid];
                        NSString* find = [pattern objectForKey:@"find"];
                        if([find isEqualToString:chunk]) {
                            NSArray* rules = [pattern objectForKey:@"rules"];
                            for(NSDictionary* rule in rules) {
                                
                                BOOL replace = TRUE;
                                int chk = 0;
                                NSArray* matches = [rule objectForKey:@"matches"];
                                for(NSDictionary* match in matches) {
                                    NSString* value = [match objectForKey:@"value"];
                                    NSString* type = [match objectForKey:@"type"];
                                    NSString* scope = [match objectForKey:@"scope"];
                                    BOOL isNegative = [[match objectForKey:@"negative"] boolValue];
                                    
                                    if([type isEqualToString:@"suffix"]) {
                                        chk = end;
                                    } 
                                    // Prefix
                                    else {
                                        chk = start - 1;
                                    }
                                    
                                    // Beginning
                                    if([scope isEqualToString:@"punctuation"]) {
                                        if(
                                           ! (
                                              (chk < 0 && [type isEqualToString:@"prefix"]) || 
                                              (chk >= len && [type isEqualToString:@"suffix"]) || 
                                              [self isPunctuation:[fixed characterAtIndex:chk]]
                                              ) ^ isNegative
                                           ) {
                                            replace = FALSE;
                                            break;
                                        }
                                    }
                                    // Vowel
                                    else if([scope isEqualToString:@"vowel"]) {
                                        if(
                                           ! (
                                              (
                                               (chk >= 0 && [type isEqualToString:@"prefix"]) || 
                                               (chk < len && [type isEqualToString:@"suffix"])
                                               ) && 
                                              [self isVowel:[fixed characterAtIndex:chk]]
                                              ) ^ isNegative
                                           ) {
                                            replace = FALSE;
                                            break;
                                        }
                                    }
                                    // Consonant
                                    else if([scope isEqualToString:@"consonant"]) {
                                        if(
                                           ! (
                                              (
                                               (chk >= 0 && [type isEqualToString:@"prefix"]) || 
                                               (chk < len && [type isEqualToString:@"suffix"])
                                               ) && 
                                              [self isConsonant:[fixed characterAtIndex:chk]]
                                              ) ^ isNegative
                                           ) {
                                            replace = FALSE;
                                            break;
                                        }
                                    }
                                    // Exact
                                    else if([scope isEqualToString:@"exact"]) {
                                        int s, e;
                                        if([type isEqualToString:@"suffix"]) {
                                            s = end;
                                            e = end + [value length];
                                        } 
                                        // Prefix
                                        else {
                                            s = start - [value length];
                                            e = start;
                                        }
                                        if(![self isExact:value heystack:fixed start:s end:e not:isNegative]) {
                                            replace = FALSE;
                                            break;
                                        }
                                    }
                                }
                                
                                if(replace) {
                                    [output appendString:[rule objectForKey:@"replace"]];
                                    [output appendString:@"(্[যবম])?(্?)([ঃঁ]?)"];
                                    cur = end - 1;
                                    matched = TRUE;
                                    break;
                                }
                                
                            }
                            
                            if(matched == TRUE) break;
                            
                            // Default
                            [output appendString:[pattern objectForKey:@"replace"]];
                            [output appendString:@"(্[যবম])?(্?)([ঃঁ]?)"];
                            cur = end - 1;
                            matched = TRUE;
                            break;
                        }
                        else if ([find length] > [chunk length] || 
                                 ([find length] == [chunk length] && [find compare:chunk] == NSOrderedAscending)) {
                            left = mid + 1;
                        } else {
                            right = mid - 1;
                        }
                    }
                    if(matched == TRUE) break;                
                }
            }
            
            if(!matched) {
                unichar oldChar = [fixed characterAtIndex:cur];
                [output appendString:[NSString stringWithCharacters:&oldChar length:1]];
            }
            // NSLog(@"cur: %s, start: %s, end: %s, prev: %s\n", cur, start, end, prev);
        }
        
        [output autorelease];
        
        return output;
    }
}

- (BOOL)isVowel:(unichar)c {
    @synchronized(self) {
        // Making it lowercase for checking
        c = [self smallCap:c];
        int i, len = [_vowel length];
        for (i = 0; i < len; ++i) {
            if ([_vowel characterAtIndex:i] == c) {
                return TRUE;
            }
        }
        return FALSE;
    }
}

- (BOOL)isConsonant:(unichar)c {
	@synchronized(self) {
        // Making it lowercase for checking
        c = [self smallCap:c];
        int i, len = [_consonant length];
        for (i = 0; i < len; ++i) {
            if ([_consonant characterAtIndex:i] == c) {
                return TRUE;
            }
        }
        return FALSE;
    }
}

- (BOOL)isPunctuation:(unichar)c {
    @synchronized(self) {
        return !([self isVowel:c] || [self isConsonant:c]);
    }
}

- (BOOL)isCaseSensitive:(unichar)c {
    @synchronized(self) {
        // Making it lowercase for checking
        c = [self smallCap:c];
        int i, len = [_casesensitive length];
        for (i = 0; i < len; ++i) {
            if ([_casesensitive characterAtIndex:i] == c) {
                return TRUE;
            }
        }
        return FALSE;
    }
}

- (BOOL)isExact:(NSString*) needle heystack:(NSString*)heystack start:(int)start end:(int)end not:(BOOL)not {
    @synchronized(self) {
        int len = end - start;
        return ((start >= 0 && end < [heystack length] 
                 && [[heystack substringWithRange:NSMakeRange(start, len)] isEqualToString:needle]) ^ not);
    }
}

- (unichar)smallCap:(unichar) letter {
    @synchronized(self) {
        if(letter >= 'A' && letter <= 'Z') {
            letter = letter - 'A' + 'a';
        }
        return letter;
    }
}

- (NSString*)clean:(NSString *)string {
    @synchronized(self) {
        NSMutableString* fixed = [[NSMutableString alloc] initWithCapacity:0];
        int i, len = [string length];
        for (i = 0; i < len; ++i) {
            unichar c = [string characterAtIndex:i];
            if (![self isCaseSensitive:c]) {
                [fixed appendFormat:@"%C", [self smallCap:c]];
            }
        }
        [fixed autorelease];
        return fixed;
    }
}
@end