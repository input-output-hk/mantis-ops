use anyhow::{Context, Result};
use percentage::Percentage;
use restson::RestClient;
use stat::{RPCData, RPCRender, RPCResult};
use std::env;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

mod stat;

#[macro_use]
extern crate log;

fn main() -> Result<()> {
    pretty_env_logger::init();

    let (tx, rx) = mpsc::channel();

    let hours: u64 = match env::args().nth(1) {
        Some(num) => num.parse::<u64>().with_context(|| {
            format!(
        "Takes the number of hours to wait before timing out.\nYou passed: {}"
        , num)
        })?,
        None => 12,
    };
    thread::spawn(move || {
        stat::timeout(hours);
        tx.send(0).unwrap();
    });

    let mantis_rpc_addr = env::var("RPC_NODE")?;
    debug!("RPC_NODE is {}", mantis_rpc_addr);

    let mut client = RestClient::new(&mantis_rpc_addr)?;

    let data: RPCData = RPCData {
        jsonrpc: String::from("2.0"),
        method: String::from("eth_syncing"),
        params: vec![],
        id: 1,
    };
    debug!("posting to {}:\n{:#?}", mantis_rpc_addr, data);

    let ratio = Percentage::from(2);

    loop {
        let response: RPCRender = client.post_capture((), &data)?;
        debug!("response:\n{:#?}", response);

        let (highest_block, current_block) = match response.result {
            RPCResult::Success(result) => {
                (result.highest_block, result.current_block)
            }
            RPCResult::Failure(_) => (0, 0),
        };

        info!(
            "{} blocks left until synced.",
            highest_block - current_block
        );
        debug!(
            "block height: {}, current position: {}.",
            highest_block, current_block
        );

        let delta = ratio.apply_to(highest_block);

        if (highest_block, current_block) == (0, 0)
            || current_block < highest_block - delta
        {
            thread::sleep(Duration::new(300, 0));
            if rx.try_recv().is_err() {
                continue;
            } else {
                break;
            };
        }

        break;
    }

    rx.recv()?;

    Ok(())
}
