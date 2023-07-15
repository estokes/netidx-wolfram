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

subscriptionHandler[taskObject_, "update", updates_] := Map[
	Function[l, Map[
		Function[f, f[l[[2]]]], 
		subscriptions[l[[1]]]]
	], 
	updates
];

dllPath = FileNameJoin[{$UserBaseDirectory, "ApplicationData", "Paclets", "PacletName", 
     "LibraryResources", $SystemID, "libnetidx_wolfram"}];

subscriptionTask = Internal`CreateAsynchronousTask[
	LibraryFunctionLoad[dllPath, "start_netidx_subscriber", {}, Integer], 
	{}, 
	subscriptionHandler
];

doSubscribe = LibraryFunctionLoad[dllPath, "subscribe", {String}, "Void"];
doUnsubscribe = LibraryFunctionLoad[dllPath, "unsubscribe", {String}, "Void"];

Subscribe[path_, f_] := Module[{id, s},
  id = callbackId;
  callbackId = callbackId + 1;
  If[MissingQ[subscriptions[path]], subscriptions[path] = <||>];
  subscriptions[path][id] = f;
  doSubscribe[path];
  id
]

Unsubscribe[path_, id_] := Module[{p},
  p = subscriptions[path];
  If[!MissingQ[p],
    If[!MissingQ[p[id]],
      Module[{},
        subscriptions[path] = KeyDropFrom[p, id];
        If[subscriptions[path] == <||>, Module[{}, 
          KeyDropFrom[subscriptions, path]; 
          doUnsubscribe[path];]
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
