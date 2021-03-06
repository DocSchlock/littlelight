import 'dart:async';

import 'package:bungie_api/models/destiny_inventory_item_definition.dart';
import 'package:bungie_api/models/destiny_item_component.dart';
import 'package:bungie_api/models/destiny_item_instance_component.dart';
import 'package:bungie_api/models/destiny_objective_definition.dart';
import 'package:bungie_api/models/destiny_objective_progress.dart';
import 'package:flutter/material.dart';
import 'package:little_light/services/auth/auth.service.dart';
import 'package:little_light/services/notification/notification.service.dart';
import 'package:little_light/widgets/common/destiny_item.stateful_widget.dart';
import 'package:little_light/widgets/common/header.wiget.dart';
import 'package:little_light/widgets/common/objective.widget.dart';
import 'package:little_light/widgets/common/translated_text.widget.dart';

class ItemObjectivesWidget extends DestinyItemStatefulWidget {
  final NotificationService broadcaster = NotificationService();
  ItemObjectivesWidget(
      DestinyItemComponent item,
      DestinyInventoryItemDefinition definition,
      DestinyItemInstanceComponent instanceInfo,
      {Key key,
      String characterId})
      : super(item, definition, instanceInfo,
            key: key, characterId: characterId);

  @override
  ItemObjectivesWidgetState createState() {
    return ItemObjectivesWidgetState();
  }
}

class ItemObjectivesWidgetState extends DestinyItemState<ItemObjectivesWidget> {
  Map<int, DestinyObjectiveDefinition> objectiveDefinitions;
  List<DestinyObjectiveProgress> itemObjectives;
  StreamSubscription<NotificationEvent> subscription;

  @override
  void initState() {
    super.initState();
    loadDefinitions();
    subscription = widget.broadcaster.listen((event) {
      if (event.type == NotificationType.receivedUpdate ||
          event.type == NotificationType.localUpdate && mounted) {
        itemObjectives =
            widget.profile.getItemObjectives(widget.item.itemInstanceId);
        setState(() {});
      }
    });
  }

    @override
  dispose() {
    subscription.cancel();
    super.dispose();
  }

  loadDefinitions() async {
    if(AuthService().isLogged){
      itemObjectives = widget.profile.getItemObjectives(item?.itemInstanceId);
    }
    objectiveDefinitions = await widget.manifest
        .getDefinitions<DestinyObjectiveDefinition>(
            definition?.objectives?.objectiveHashes);
    if(mounted){
      setState(() {});
    }
    
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    if ((objectiveDefinitions?.length ?? 0) == 0) return Container();

    items.add(Container(
        padding: EdgeInsets.all(8),
        child: HeaderWidget(
            child: TranslatedTextWidget("Objectives",
                uppercase: true,
                style: TextStyle(fontWeight: FontWeight.bold)))));
    items.addAll(buildObjectives(context));
    return Column(children: items);
  }

  List<Widget> buildObjectives(BuildContext context) {
    if (itemObjectives != null) {
      return itemObjectives
          .map((objective) => buildCurrentObjective(context, objective.objectiveHash, objective))
          .toList();
    }
    return definition.objectives.objectiveHashes
        .map((hash) => buildCurrentObjective(context, hash))
        .toList();
  }

  Widget buildCurrentObjective(BuildContext context, int hash,
      [DestinyObjectiveProgress objective]) {
    var def = objectiveDefinitions[hash];
    return 
        Container(
          padding: EdgeInsets.all(8),
          child:ObjectiveWidget(
          definition: def,
          objective: objective,
        ));
  }
}
