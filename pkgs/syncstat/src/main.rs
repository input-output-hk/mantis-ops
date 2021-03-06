use anyhow::{anyhow, Context, Result};
use percentage::Percentage;
use restson::RestClient;
use stat::{RPCData, RPCRender, RPCResult};
use std::env;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

mod stat;

#[macro_use]
extern crate log;

#[tokio::main]
async fn main() -> Result<()> {
    pretty_env_logger::init();

    let start_time = Instant::now();

    let (tx, rx) = mpsc::channel();

    let hours: u64 = match env::args().nth(1) {
        Some(num) => num.parse::<u64>().with_context(|| {
            format!(
        "Takes the number of hours to wait before timing out.\nYou passed: {}"
        , num)
        })?,
        None => 12,
    };

    let timer = thread::spawn(move || {
        stat::timeout(hours);
        tx.send(()).unwrap();
    });

    let mantis_rpc_addr = env::var("RPC_NODE")?;
    debug!("RPC_NODE is {}", mantis_rpc_addr);

    let mut client = RestClient::new(&mantis_rpc_addr)?;

    let slack_path = env::var("SLACK_PATH")?;

    let job = env::var("NOMAD_JOB_NAME")?;

    stat::post_slack(
        &job,
        &slack_path,
        &format!("Starting a sync that will timeout in {} hours", hours),
    )
    .await?;

    let data: RPCData = RPCData {
        jsonrpc: String::from("2.0"),
        method: String::from("eth_syncing"),
        params: vec![],
        id: 1,
    };
    debug!("posting to {}:\n{:#?}", mantis_rpc_addr, data);

    let ratio = Percentage::from(2);

    loop {
        let response: RPCRender =
            client.post_capture((), &data).unwrap_or_default();
        debug!("response:\n{:#?}", response);

        let (highest_block, current_block) = match response.result {
            RPCResult::Success(result) => {
                (result.highest_block, result.current_block)
            }
            RPCResult::Failure(_) => (0, 0),
        };

        info!("{}", stat::format_time(start_time.elapsed().as_secs()));

        let delta = ratio.apply_to(highest_block);

        if (highest_block, current_block) == (0, 0)
            || current_block < highest_block - delta
        {
            thread::sleep(Duration::new(300, 0));
            if rx.try_recv().is_err() {
                continue;
            } else {
                let message = format!(
                    "Timed out after {} hours, before sync completed.",
                    hours
                );

                stat::post_slack(&job, &slack_path, &message).await?;

                info!("{}", message);

                let err: Result<()> = Err(anyhow!(message));
                return err;
            };
        }
        break;
    }

    let message = format!(
        "Sync completed.\n{}",
        stat::format_time(start_time.elapsed().as_secs())
    );

    stat::post_slack(&job, &slack_path, &message).await?;

    info!("{}", message);

    timer.join().ok();

    Ok(())
}
