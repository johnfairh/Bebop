// ObjC header to test/demo ObjC->Swift extensions, name-mapping

@import Foundation;

/// Un-renamed class to check normal things still work
@interface NormalClass : NSObject
- (void)objcNormalMethod;
@end

/// Type with different name in Swift
NS_SWIFT_NAME(Kitchen)
@interface JMLKitchen : NSObject
- (void)jmlKitchenMethod NS_SWIFT_NAME(kitchenMethod());
@end

/// Type with a different shape in Swift - parent exists
NS_SWIFT_NAME(Kitchen.Cupboard)
@interface JMLKitchenCupboard : NSObject
-(void)jmlKitchenCupboardMethod;
@end

/// Type with a different shape in Swift - parent does not exist
NS_SWIFT_NAME(Bathroom.Cupboard)
@interface JMLBathroomCupboard : NSObject
-(void)jmlBathroomCupboardMethod;
@end
