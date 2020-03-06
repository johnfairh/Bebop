// ObjC header to test/demo ObjC->Swift extensions, name-mapping

#import "SpmObjCModule.h"

/// Un-renamed class to check normal things still work
@implementation NormalClass
- (void)objcNormalMethod {}
@end

/// Type with different name in Swift
@implementation JMLKitchen
- (void)jmlKitchenMethod {}
@end

/// Type with a different shape in Swift - parent exists
@implementation JMLKitchenCupboard
-(void)jmlKitchenCupboardMethod {}
@end

/// Type with a different shape in Swift - parent does not exist
@implementation JMLBathroomCupboard
-(void)jmlBathroomCupboardMethod {}
@end
