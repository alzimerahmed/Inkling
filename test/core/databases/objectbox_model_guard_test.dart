import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Migration guard for the ObjectBox schema (`lib/objectbox-model.json`).
///
/// ObjectBox entity/property UIDs are the identity of stored data: if codegen
/// reassigns a UID (usually caused by deleting/renaming a property, or letting
/// the generator regenerate the model file), existing on-device stores can no
/// longer be opened — the #1 data-loss vector in this app.
///
/// This test pins the UID of every entity and property. A failure means the
/// model changed in a way that needs explicit attention:
/// - intentional rename → keep the old property, add a new one, migrate data;
/// - intentional new property → regenerate the snapshot below (append-only);
/// - accidental regeneration → restore the previous `objectbox-model.json`.
void main() {
  test('ObjectBox model UIDs are stable (no destructive schema drift)', () {
    final File modelFile = File('lib/objectbox-model.json');
    expect(
      modelFile.existsSync(),
      isTrue,
      reason: 'objectbox-model.json must stay checked in',
    );

    final List<dynamic> entities = jsonDecode(
      modelFile.readAsStringSync(),
    )['entities'];

    String snapshotOf(Map<String, dynamic> entity) {
      final List<String> properties =
          (entity['properties'] as List)
              .map((property) => '${property['name']}=${property['id']}')
              .toList()
            ..sort();
      return ['${entity['name']}=${entity['id']}', ...properties].join('|');
    }

    // Snapshot taken at the Inkling fork point (upstream 2.33.1). To extend
    // the schema legitimately: add the property in code, run build_runner,
    // then append the new "Name=id|...|newProp=uid" line below. Never edit or
    // remove an existing line.
    const List<String> expectedSnapshots = [
      'StoryObjectBox=1:2962579780537594759'
          '|assets=24:7561688432028578210'
          '|changes=12:5871534476772289101'
          '|characterCount=36:3051838431030192697'
          '|createdAt=9:4952094039664744075'
          '|day=6:3490487563053838054'
          '|draftContent=29:2326009534719657446'
          '|feeling=8:7221060550241170408'
          '|galleryTemplateId=32:5877908410429539901'
          '|hour=18:1429297690659026930'
          '|id=1:97606503289813034'
          '|lastSavedDeviceId=22:7678166380701811232'
          '|latestContent=28:421098968365083050'
          '|latitude=37:6787714761444359568'
          '|longitude=38:6206608334633774136'
          '|minute=19:862060011000399226'
          '|month=5:3493347036869873160'
          '|movedToBinAt=11:9125848120865526787'
          '|permanentlyDeletedAt=21:5147940647382545592'
          '|pinned=34:6588339555158711350'
          '|place=39:2142887574017047798'
          '|placeName=40:5221629383960840754'
          '|preferences=25:5807327571729293497'
          '|searchMetadata=33:6880637040027848499'
          '|second=20:4113637293536721721'
          '|starred=7:6774169397346542505'
          '|tags=13:6005849190320169908'
          '|templateId=30:5473653846024956989'
          '|type=3:1455186831852939171'
          '|updatedAt=10:4961981479060558999'
          '|version=2:6285480559740659261'
          '|wordCount=35:84094890273270909'
          '|year=4:4895366266528452927',
      'TagObjectBox=2:5548558812249966101'
          '|categoryId=12:2093176491331659474'
          '|createdAt=6:3746821438504660808'
          '|emoji=5:3138951263147849158'
          '|id=1:5046052891972916251'
          '|index=8:6011272584059291333'
          '|lastSavedDeviceId=10:1120015455933452719'
          '|permanentlyDeletedAt=9:4397546260987904187'
          '|title=2:8744880092533568590'
          '|updatedAt=7:4116584270770327746'
          '|version=3:7863427692914238443',
      'PreferenceObjectBox=4:8652388247732271380'
          '|createdAt=4:5487565668895572636'
          '|id=1:5845189424486968777'
          '|key=2:7879389423381012812'
          '|lastSavedDeviceId=7:4080067487898077389'
          '|permanentlyDeletedAt=6:7741946128893402175'
          '|updatedAt=5:6079525654333709276'
          '|value=3:6346675735678687120',
      'AssetObjectBox=5:4094713120589114734'
          '|cloudDestinations=3:9061464992410544713'
          '|createdAt=4:7161480163824462596'
          '|height=15:1493334910848739574'
          '|id=1:5906669873848364603'
          '|lastSavedDeviceId=7:5781354513111192719'
          '|metadata=11:3385039821200523280'
          '|originalSource=8:1856515659629711057'
          '|permanentlyDeletedAt=6:7819533052746471106'
          '|tags=12:7750389189867599724'
          '|type=10:3842512515517858228'
          '|updatedAt=5:4609595509255257773'
          '|version=13:8859144998009161825'
          '|width=14:2230481197199389868',
      'TemplateObjectBox=6:4197752153260494722'
          '|archivedAt=10:3267732544409712890'
          '|content=4:5109357445308744818'
          '|createdAt=5:2667031694050257510'
          '|galleryTemplateId=13:7711936533008164879'
          '|id=1:4888786211485405431'
          '|index=2:965504840504950186'
          '|lastSavedDeviceId=8:7677675212420904566'
          '|name=12:7449546806323438363'
          '|note=11:9213761210184601049'
          '|permanentlyDeletedAt=7:7271579894459585661'
          '|preferences=9:7022531881534829655'
          '|tags=3:8534163020409733992'
          '|updatedAt=6:7266303846030833481',
      'RelaxSoundMixBox=7:7447837682900434922'
          '|createdAt=4:713199041146636257'
          '|id=1:313537167867615676'
          '|index=8:5312486173104212263'
          '|lastSavedDeviceId=7:764543406322651921'
          '|name=2:4518666253956758444'
          '|permanentlyDeletedAt=6:359413979246993001'
          '|sounds=3:8484003766353545544'
          '|updatedAt=5:7838093783314215653',
      'EventObjectBox=8:4141544638649465889'
          '|createdAt=6:4105040820472222305'
          '|day=4:5471026013882178136'
          '|eventType=5:7259485360492887599'
          '|id=1:7778167802137349235'
          '|lastSavedDeviceId=9:7724360977652119040'
          '|month=3:1817316657179753326'
          '|permanentlyDeletedAt=8:6580784597345938449'
          '|updatedAt=7:6528294432714917018'
          '|year=2:8514330305809733913',
      'TagCategoryObjectBox=10:6875722368332154421'
          '|createdAt=7:8290431425631655667'
          '|id=1:8447154602269222328'
          '|index=5:7305675005364225177'
          '|lastSavedDeviceId=10:1586171392323133748'
          '|multiSelect=3:4800807500656422913'
          '|permanentlyDeletedAt=9:1747783703445985427'
          '|system=4:2424685804451881967'
          '|title=2:2122632392509580275'
          '|updatedAt=8:2832184903213716384'
          '|version=6:5615958948791855505',
    ];

    final Set<String> current = entities
        .map((entity) => snapshotOf(entity as Map<String, dynamic>))
        .toSet();
    final Set<String> expected = expectedSnapshots.toSet();

    final Set<String> removed = expected.difference(current);
    final Set<String> added = current.difference(expected);

    expect(
      removed,
      isEmpty,
      reason:
          'ObjectBox entities/properties were removed or had UIDs reassigned: $removed. '
          'Existing on-device stores will fail to open. Restore the previous objectbox-model.json.',
    );

    expect(
      added,
      isEmpty,
      reason:
          'New ObjectBox entities/properties detected: $added. If this change is intentional '
          '(non-destructive addition), regenerate the snapshot in objectbox_model_guard_test.dart '
          'by appending the new lines. If not, restore the previous objectbox-model.json.',
    );
  });
}
