use percentage::Percentage;
use restson::{RestClient, RestPath};
use serde::{Deserialize, Serialize};
use serde_hex::{CompactPfx, SerHex};
use std::env;
use std::error::Error;
use std::process;
use std::thread;
use std::time::Duration;

#[derive(Debug, Serialize, Deserialize)]
pub struct RPCRender {
    pub jsonrpc: String,
    pub result: RPCResult,
    pub id: i32,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ResultSuccess {
    #[serde(rename = "startingBlock")]
    #[serde(with = "SerHex::<CompactPfx>")]
    pub starting_block: u64,
    #[serde(rename = "currentBlock")]
    #[serde(with = "SerHex::<CompactPfx>")]
    pub current_block: u64,
    #[serde(rename = "highestBlock")]
    #[serde(with = "SerHex::<CompactPfx>")]
    pub highest_block: u64,
    #[serde(rename = "knownStates")]
    #[serde(with = "SerHex::<CompactPfx>")]
    pub known_states: u64,
    #[serde(rename = "pulledStates")]
    #[serde(with = "SerHex::<CompactPfx>")]
    pub pulled_states: u64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RPCResult {
    Success(ResultSuccess),
    Failure(bool),
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RPCData {
    pub jsonrpc: String,
    pub method: String,
    pub params: Vec<String>,
    pub id: i32,
}

impl RestPath<()> for RPCData {
    fn get_path(_: ()) -> Result<String, restson::Error> {
        Ok("".to_string())
    }
}

fn timeout(seconds: u64) {
    thread::sleep(Duration::new(seconds, 0));
    eprintln!("timed out after {} seconds", seconds);
    process::exit(1)
}

fn main() -> Result<(), Box<dyn Error>> {
    thread::spawn(|| timeout(60 * 60 * 12));

    let mantis_rpc_addr = env::var("RPC_NODE")?;
    println!("RPC_NODE is {}", mantis_rpc_addr);
    let mut client = RestClient::new(&mantis_rpc_addr)?;

    let data: RPCData = RPCData {
        jsonrpc: String::from("2.0"),
        method: String::from("eth_syncing"),
        params: vec![],
        id: 1,
    };

    let ratio = Percentage::from(2);

    loop {
        let response: RPCRender = client.post_capture((), &data)?;

        let (highest_block, current_block) = match response.result {
            RPCResult::Success(result) => {
                (result.highest_block, result.current_block)
            }
            RPCResult::Failure(_) => (0, 0),
        };

        let delta = ratio.apply_to(highest_block);

        if (highest_block, current_block) == (0, 0)
            || current_block < highest_block - delta
        {
            thread::sleep(Duration::new(30, 0));
            continue;
        }

        break;
    }

    Ok(())
}
