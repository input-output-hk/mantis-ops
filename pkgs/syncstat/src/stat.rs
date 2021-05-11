use restson::RestPath;
use serde::{Deserialize, Serialize};
use serde_hex::{CompactPfx, SerHex};
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

pub fn timeout(hours: u64) {
    info!("Mantis node will run for {} hours.", hours);
    thread::sleep(Duration::new(hours * 60 * 60, 0));
}
