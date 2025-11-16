#import <Foundation/Foundation.h>

// Definição da classe principal do tweak
@interface BLSbxAutomator : NSObject

// Método principal para iniciar a exploração
- (BOOL)startExploit;

// Métodos auxiliares
- (NSString *)findBLDatabaseManagerUUID;
- (BOOL)modifyDownloadsDBWithUUID:(NSString *)uuid;
- (BOOL)injectFilesForStage:(int)stage withUUID:(NSString *)uuid;
- (BOOL)restartDaemon:(NSString *)daemonName;

@end
