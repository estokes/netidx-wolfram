use futures::{channel::mpsc, prelude::*, select_biased};
use fxhash::FxHashMap;
use netidx::{
    config::Config,
    path::Path,
    subscriber::{Dval, Event, SubId, Subscriber, UpdatesFlags, Value},
};
use once_cell::sync::OnceCell;
use rust_decimal::prelude::*;
use std::collections::{hash_map::Entry, HashMap};
use tokio::runtime::Runtime;
use wolfram_library_link::{self as wll, AsyncTaskObject, DataStore};

wll::generate_loader!(load_netidx_functions);

static TO: OnceCell<mpsc::UnboundedSender<Path>> = OnceCell::new();

fn add_netidx_val(ds: &mut DataStore, v: &Value) {
    match v {
        Value::F32(f) => ds.add_f64(*f as f64),
        Value::F64(f) => ds.add_f64(*f as f64),
        Value::I32(i) => ds.add_i64(*i as i64),
        Value::V32(i) => ds.add_i64(*i as i64),
        Value::Z32(i) => ds.add_i64(*i as i64),
        Value::U32(i) => ds.add_i64(*i as i64),
        Value::U64(i) => ds.add_i64(*i as i64),
        Value::V64(i) => ds.add_i64(*i as i64),
        Value::I64(i) => ds.add_i64(*i),
        Value::Z64(i) => ds.add_i64(*i),
        Value::String(s) => ds.add_str(&**s),
        Value::True => ds.add_bool(true),
        Value::False => ds.add_bool(false),
        Value::DateTime(dt) => ds.add_str(&dt.to_string()),
        Value::Duration(d) => ds.add_f64(d.as_secs_f64()),
        Value::Decimal(d) => {
            if let Some(d) = d.to_f64() {
                ds.add_f64(d)
            }
        }
        Value::Error(e) => ds.add_str(&format!("Error: {}", e)),
        Value::Ok => ds.add_str("Ok"),
        // CR estokes: implement
        Value::Null => (),
        Value::Bytes(_) => (),
        Value::Array(a) => {
            let mut inner = DataStore::new();
            for v in &**a {
                add_netidx_val(&mut inner, v)
            }
            ds.add_data_store(inner)
        }
    }
}

async fn run_subscriber(task: AsyncTaskObject) {
    let config = Config::load_default().expect("could not load netidx config");
    let auth = config.default_auth();
    let subscriber = Subscriber::new(config, auth).expect("could not create netidx subscriber");
    let mut by_path: FxHashMap<Path, SubId> = HashMap::default();
    let mut by_subid: FxHashMap<SubId, (Path, Dval)> = HashMap::default();
    let (tx_up, mut rx_up) = mpsc::channel(3);
    let (tx, mut rx) = mpsc::unbounded();
    TO.set(tx).expect("failed to set to");
    loop {
        #[rustfmt::skip]
	select_biased! {
            path = rx.select_next_some() => {
                if let Entry::Vacant(e) = by_path.entry(path.clone()) {
		    let sub = subscriber.subscribe(path.clone());
		    sub.updates(UpdatesFlags::BEGIN_WITH_LAST, tx_up.clone());
		    e.insert(sub.id());
		    by_subid.insert(sub.id(), (path, sub));
                }
            },
            mut batch = rx_up.select_next_some() => {
		let mut res = DataStore::new();
		for (id, ev) in batch.drain(..) {
		    match ev {
			Event::Unsubscribed => (),
			Event::Update(v) => {
			    let mut up = DataStore::new();
			    up.add_str(&*by_subid[&id].0);
			    add_netidx_val(&mut up, &v);
			    res.add_data_store(up);
			}
		    }
		}
		task.raise_async_event("update", res)
            },
	    complete => break,
        }
    }
}

#[wll::export]
fn start_netidx_subscriber() -> i64 {
    let task = AsyncTaskObject::spawn_with_thread(|task: AsyncTaskObject| {
        let mut _rt = Runtime::new()
            .expect("could not create runtime")
            .block_on(run_subscriber(task));
    });
    task.id()
}

#[wll::export]
fn subscribe(path: String) {
    TO.get()
        .expect("you must initialize netidx")
        .unbounded_send(Path::from(path))
        .expect("failed to subscribe");
}
