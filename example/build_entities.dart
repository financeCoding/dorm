import 'dart:async';
import 'dart:io';
import 'dart:json';

void main() {
  loadDefinitions();
}

void createDomainFile(List<String> classes, List<String> entityClassNames) {
  Directory directory = new Directory('../example/orm_domain');
  
  if (!directory.existsSync()) {
    directory.createSync();
  }
  
  String contents = '';
  File domainFile = new File('../example/orm_domain/orm_domain.dart');
  
  contents += 'library orm_domain;\r\r';
  contents += "import 'package:dorm/dorm.dart';\r\r";
  
  classes.forEach(
    (String className) => contents += "part '${className}.dart';\r" 
  );
  
  contents += '\r';
  
  contents += 'void ormInitialize() {\r';
  contents += '\tEntityManager entityManager = new EntityManager();\r\r';
  
  entityClassNames.forEach(
    (String entityClassName) => contents += '\tentityManager.scan(${entityClassName});\r'    
  );
  
  contents += '}\r';
  
  domainFile.create().then(
      (File createdFile) {
        createdFile.writeAsString(contents, mode:FileMode.WRITE , encoding:Encoding.UTF_8);
      }
  );
}

String create(File file, String fileContent) {
  Map entityMap = parse(fileContent);
  
  List<String> tmp = file.path.replaceAll(new RegExp('[^a-zA-Z0-9_]+'), '.').split('.');
  
  tmp.removeLast();
  
  String partA = tmp.removeLast();
  
  String ref = '${tmp.removeLast()}.$partA';
  String fileName = '$partA.dart';
  bool isMutableEntity = true;
  
  if (
    entityMap.containsKey('cache-use') &&
    entityMap['cache-use'] == 'read-only'
  ) {
    isMutableEntity = false;
  }
  
  String contents = '// Generated by build_entities.dart,\r// rerun this script if you have made changes\r// to the corresponding server-side Hibernate file\r\r';
  
  contents += 'part of orm_domain;\r\r';
  
  contents += "@Ref('$ref')\r";
  
  if (!isMutableEntity) {
    contents += "@Immutable()\r";
  }
  
  if (entityMap.containsKey('extends')) {
    contents += 'class ${entityMap['name']} extends ${entityMap['extends']} {';
  } else {
    contents += 'class ${entityMap['name']} extends Entity {';
  }
  
  contents += '\r';
  contents += '\r';
  
  if (entityMap.containsKey('properties')) {
    List<Map> properties = entityMap['properties'];
    
    contents += addBigBlock('Public properties');
    
    properties.forEach(
      (Map propertyMap) {
        contents += addSmallBlock(propertyMap['name']);
        
        contents += "\t@Property(${propertyMap['name'].toUpperCase()}_SYMBOL, '${propertyMap['name']}')\r";
        
        if (
            propertyMap.containsKey('identity') &&
            (propertyMap['identity'] == true)
        ) {
          contents += '\t@Id()\r';
          contents += '\t@NotNullable()\r';
        }
        
        if (propertyMap.containsKey('insert-when')) {
          contents += '\t@DefaultValue(${propertyMap['insert-when']})\r';
        }
        
        if (
            propertyMap.containsKey('persistent') &&
            (propertyMap['persistent'] == false)
        ) {
          contents += '\t@Transient()\r';
        }
        
        if (
            propertyMap.containsKey('nullable') &&
            (propertyMap['nullable'] == false)
        ) {
          contents += '\t@NotNullable()\r';
        }
        
        if (
            (
              propertyMap.containsKey('cache-use') &&
              (propertyMap['cache-use'] == 'read-only')
            ) ||
            (
              propertyMap.containsKey('identity') &&
              (propertyMap['identity'] == true)    
            )
        ) {
          contents += '\t@Immutable()\r';
        }
        
        if (
            propertyMap.containsKey('label-field') &&
            (propertyMap['label-field'] == true)
        ) {
          contents += '\t@LabelField()\r';
        }
        
        contents += '\tProxy<${propertyMap['type']}> _${propertyMap['name']};\r\r';
        contents += "\tstatic const String ${propertyMap['name'].toUpperCase()} = '${propertyMap['name']}';\r";
        contents += "\tstatic const Symbol ${propertyMap['name'].toUpperCase()}_SYMBOL = const Symbol('orm_domain.${entityMap['name']}.${propertyMap['name']}');\r\r";
        contents += '\t${propertyMap['type']} get ${propertyMap['name']} => _${propertyMap['name']}.value;\r';
        contents += "\tset ${propertyMap['name']}(${propertyMap['type']} value) => _${propertyMap['name']}.value = notifyPropertyChange(${propertyMap['name'].toUpperCase()}_SYMBOL, _${propertyMap['name']}.value, value);\r\r";
      }
    );
  }
  
  contents += addBigBlock('Constructor');
  
  contents += '\t${entityMap['name']}() : super();\r\r';
  
  contents += '}';
  
  Directory directory = new Directory('../example/orm_domain');
  
  if (!directory.existsSync()) {
    directory.createSync();
  }
  
  File clientFile = new File('../example/orm_domain/' + fileName);
  
  clientFile.create().then(
      (File createdFile) {
        createdFile.writeAsString(contents, mode:FileMode.WRITE , encoding:Encoding.UTF_8);
      }
  );
  
  return entityMap['name'];
}

String addSmallBlock(String blockName) {
  return '\t//---------------------------------\r\t// $blockName\r\t//---------------------------------\r\r';
}

String addBigBlock(String blockName) {
  return '\t//---------------------------------\r\t//\r\t// $blockName\r\t//\r\t//---------------------------------\r\r';
}

void loadDefinitions() {
  Directory dir = new Directory('../bin/entities');
  
  Future<List<FileSystemEntity>> listing = getDefinitionFiles(dir);
  
  listing.then(getDefinitionFiles_completeHandler);
}

Future<List<FileSystemEntity>> getDefinitionFiles(Directory dir) {
  List<FileSystemEntity> files = <FileSystemEntity>[];
  Completer completer = new Completer();
  Stream<FileSystemEntity> lister = dir.list(recursive: false);
  
  lister.listen ( 
      (FileSystemEntity file) => 
          files.add(file),
          onDone: () => completer.complete(files)
  );
  
  return completer.future;
}

void getDefinitionFiles_completeHandler(List<FileSystemEntity> result) {
  List<String> classes = <String>[];
  List<String> entityClassNames = <String>[];
  
  result.forEach(
      (File file) {
        List<String> tmp = file.path.replaceAll(new RegExp('[^a-zA-Z0-9_]+'), '.').split('.');
        
        tmp.removeLast();
        
        String partA = tmp.removeLast();
        String partB = tmp.removeLast();
        
        String ref = '${partB}.$partA';
        
        classes.add(partA);
        
        String entityClassName = create(
            file, 
            file.readAsStringSync(encoding: Encoding.UTF_8)
        );
        
        entityClassNames.add(entityClassName);
      }
  );
  
  createDomainFile(classes, entityClassNames);
}