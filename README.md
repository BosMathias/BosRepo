# BosRepo

![Alt text](https://g.gravizo.com/source/custom_mark13?https%3A%2F%2Fraw.githubusercontent.com%2FTLmaK0%2Fgravizo%2Fmaster%2FREADME.md)
<details>
<summary></summary>

@startuml;

participant "Bridge" as A;
participant "Motionplanner" as B;
participant "ObstDetect" as C;

User -> A: INIT - req:global_costmap;
activate A;
A -> C: process_global_costmap/req: global_costmap;
activate C;
C -> A: resp: basic shapes room, static obstacles;
A -> B: room, static obstacles;
activate B;
deactivate B;
A -> User: Resp: None
Deactivate A

@enduml

</details>
