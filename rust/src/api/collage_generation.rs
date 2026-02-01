use anyhow::Result;
use image::{DynamicImage, ImageBuffer, Rgb};
use rayon::prelude::*;

pub async fn generate_collage(
    paths: Vec<String>,
    num_frames: i32, 
    quality: i32
) -> Result<()> {
    use rayon::prelude::*;

    // .par_iter() trasforma la lista in un iteratore parallelo magico
    paths.par_iter().for_each(|path| {
        // Chiama la tua vecchia funzione di generazione collage per il singolo file
        if let Err(e) = generate_single_collage(path, num_frames, quality) {
            eprintln!("Errore sul file {}: {}", path, e);
        }
        // Qui potresti inviare un segnale a Dart per dire "ho finito un video"
    });

    Ok(())
}

fn generate_single_collage(path: &str, num_frames: i32, quality: i32) -> Result<()> {
    use video_rs::{Decoder, Options};
    use std::path::Path;

    // 1. Apri il video
    let path_obj = Path::new(path);
    let mut decoder = Decoder::new(path_obj)?;
    
    // TODO: Qui estrarremo i frame ad intervalli regolari
    // e useremo il crate 'image' per salvarli.
    
    println!("Elaborando video: {} con {} frames", path, num_frames);
    
    Ok(())
}