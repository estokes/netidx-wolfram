(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["Netidx`"];


(* ::Text:: *)
(*Declare your public symbols here:*)


Subscribe::usage = "Subscribe[path, callback], calls callback with the value of path whenever it updates";
Unsubscribe::usage = "Unsubscribe[path, id], unsubscribes the callback named by id (returned by subscribe) from the path";
UnsubscribeAll::usage = "UnsubscribeAll[path], unsubscribes all callbacks from path"


Begin["`Private`"];


(* ::Section:: *)
(*Definitions*)


(* ::Text:: *)
(*Define your public and private symbols here:*)


callbackId = 0;

subscriptions = <||>;

subscriptionHandler[taskObject_, "update", updates_] := Function[l,
  #[l[[2]]]& /@ subscriptions[l[[1]]]
] /@ updates;

subscriptionTask = Internal`CreateAsynchronousTask[LibraryFunctionLoad[
  "libnetidx_wolfram", "start_netidx_subscriber", {}, Integer], {}, netidxHandler
  ];

doSubscribe = LibraryFunctionLoad["libnetidx_wolfram", "subscribe", {
  String}, "Void"];

doUnsubscribe = LibraryFunctionLoad["libnetidx_wolfram", "unsubscribe",
   {String}, "Void"]

Subscribe[path_, f_] := Module[{id, s},
  id = callbackId;
  callbackId = callbackId + 1;
  s = subscriptions[path];
  s = If[MissingQ[s], subscriptions[path] = <||>, s];
  s[id] = f;
  doSubscribe (path);
  id
]

Unsubscribe[path_, id_] := Module[{p},
  p = subscriptions[path];
  If[!MissingQ[p],
    If[!MissingQ[p[id]],
      Module[{},
        KeyDropFrom[p, id];
        If[p == <||>,
          Module[{},
            KeyDropFrom[subscriptions, path]; doUnsubscribe[path];
          ]
        ]
      ]
    ]
  ]
]

UnsubscribeAll[path_] := Module[{p},
  p = subscriptions[path];
  If[!MissingQ[p],
    Module[{},
      KeyDropFrom[subscriptions, path]; doUnsubscribe[path]
    ]
  ]
]


(* ::Section::Closed:: *)
(*Package Footer*)


End[];
EndPackage[];
