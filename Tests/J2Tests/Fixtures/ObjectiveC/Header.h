@import Foundation;

@interface IVarTest: NSObject {
    NSString *ivarName;
}

/** Documented property */
@property (strong) NSString *propertyName __deprecated_msg("Is deprecated");

@end

/** Various kinds of property and method*/
@interface PropertyKinds: NSObject

/** doc */
@property (class, nonatomic, copy) NSUUID *identifier;

/** Nullability */
@property (nonatomic, copy, nullable) NSUUID *uuid;

+ (instancetype) alloc;
- (id)init __deprecated;

/** No params */
- (void)method;

/** params */
- (int) doThingWith:(int) first named:(NSString *) name;

+ (void)classMethod;

@end

/* C compat*/

#pragma mark - C-only?

extern int fred __unavailable;

void global_func(void);

/** Structures */
struct AStruct {
  /** Field */
  int field;
};

/** Enums */
typedef NS_ENUM(NSInteger, AEnum) {
  /** Enum element a */
  a = 3,
  /** Enum element b */
  b = 4
};

enum ASimpleEnum {
  x,
  y
};

/** Typedef */
typedef int Fred;

/** Category */
@interface IVarTest(ACategory)

- (void)categoryMethod;

@end

/** Protocol */
@protocol SomeProtocol

-(void)protocolMethod;

@end

/** Lightweight generics */
@interface Stack<ElementType> : NSObject

/** Method with lightweight generic type param */
- (ElementType *)popWith:(NSString *)weight secondValue:(NSInteger)density;

@end
