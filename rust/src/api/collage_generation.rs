use anyhow::Result;
use rayon::prelude::*;
use crate::frb_generated::StreamSink;

pub async fn generate_collage(
    sink: StreamSink<String>, 
    paths: Vec<String>, 
    num_frames: i32, 
    quality: i32
) -> Result<()> {
    use std::time::Instant;
    let total_elaboration_time = Instant::now();

    // Creiamo il pool (come già facevi)
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(4) 
        .build()
        .map_err(|e| anyhow::anyhow!("Errore pool: {}", e))?;

    // --- LA MODIFICA È QUI ---
    // Usiamo uno scope per assicurarci che i dati vengano inviati man mano
    // Invece di .install (che è bloccante), usiamo un approccio che permette al sink di respirare
    
    pool.scope(|s| {
        for path in paths {
            let sink_inner = sink.clone();
            s.spawn(move |_| {
                match generate_single_collage(&path, num_frames, quality) {
                    Ok(_) => {
                        // Invia il path a Flutter IMMEDIATAMENTE dopo il singolo salvataggio
                        let _ = sink_inner.add(path); 
                    },
                    Err(e) => {
                        eprintln!("Errore sul file {}: {}", path, e);
                    }
                }
            });
        }
    });

    println!("✨ OPERAZIONE COMPLETATA IN: {:?}", total_elaboration_time.elapsed());
    Ok(())
}

fn generate_single_collage(path: &str, num_frames: i32, _quality: i32) -> Result<()> {
    use std::time::Instant;
    let total_start = Instant::now();
    use image::codecs::jpeg::JpegEncoder;
    use std::fs::File;
    use video_rs::{Decoder, init};
    use std::path::Path;
    use image::{RgbImage, GenericImage, imageops::FilterType};

    // Quality matches 0-4
    let (scale_factor_preset, jpeg_quality) = match _quality {
        0 => (0.15, 45),
        1 => (0.30, 60),
        2 => (0.50, 75),
        3 => (0.75, 85),
        4 => (1.00, 92),
        _ => (0.50, 75),
    };

    init().map_err(|e| anyhow::anyhow!("Errore init video-rs: {}", e))?;
    let path_obj = Path::new(path);
    let file_stem = path_obj.file_stem().and_then(|s| s.to_str()).unwrap_or("video");

    let mut decoder = Decoder::new(path_obj)?;
    let duration_secs = decoder.duration()?.as_secs_f64();
    let interval = duration_secs / (num_frames as f64);

    // Get the initial width and height
    let (initial_w, initial_h) = decoder.size();
    let mut real_w = initial_w as u32;
    let mut real_h = initial_h as u32;

    let mut raw_frames: Vec<Vec<u8>> = Vec::new();

    for i in 0..num_frames {
        let seek_ms = (i as f64 * interval * 1000.0) as i64;
        let _ = decoder.seek(seek_ms);

        // Decoding the frame
        if let Some(Ok(frame)) = decoder.decode_raw_iter().next() {
            // Convert the frame to a Vec<u8>
            let flat_data: Vec<u8> = frame.data(0).iter().cloned().collect();
            
            // SECURITY CHECK
            // If the buffer length doesn't match the expected size, 
            // it's probably a rotated frame
            let expected_len = (real_w * real_h * 3) as usize;
            
            if i == 0 && flat_data.len() != expected_len {
                // If the first frame is rotated, swap the width and height
                if flat_data.len() == (real_h * real_w * 3) as usize {
                    std::mem::swap(&mut real_w, &mut real_h);
                    println!("🔄 Rotation found via buffer len: {}x{}", real_w, real_h);
                } else {
                    // Else it's padding, so we need to calculate the real width
                    // by dividing the buffer length by the height
                    real_w = (flat_data.len() / (real_h as usize * 3)) as u32;
                    println!("📏 Stride found! New buffer width: {}", real_w);
                }
            }
            
            raw_frames.push(flat_data);
        } 
    }

    if raw_frames.is_empty() { return Err(anyhow::anyhow!("Zero frames extracted")); }

    // Calculate the final width and height
    let thumb_w = (real_w as f32 * scale_factor_preset).max(1.0) as u32;
    let thumb_h = (real_h as f32 * scale_factor_preset).max(1.0) as u32;

    // Parallel extraction
    let extracted_images: Vec<RgbImage> = raw_frames
        .into_par_iter()
        .map(|data| {
            let temp_img = RgbImage::from_raw(real_w, real_h, data)
                .expect("Fatal error: the buffer doesn't match the expected size");
            
            // FilterType::Nearest is the default, fastest but lowest in quality
            // Use Lanczos3 or Triangle for better quality but slower processing
            image::imageops::resize(&temp_img, thumb_w, thumb_h, FilterType::Nearest)
        })
        .collect();

    // Grid generation
    let columns = 8;
    let rows = (extracted_images.len() as f32 / columns as f32).ceil() as u32;
    let mut collage = RgbImage::new(thumb_w * columns, thumb_h * rows);

    for (i, img) in extracted_images.iter().enumerate() {
        let x = (i as u32 % columns) * thumb_w;
        let y = (i as u32 / columns) * thumb_h;
        let _ = collage.copy_from(img, x, y);
    }
    
    // Saving the grid
    let output_path = path_obj.parent().unwrap().join(format!("{}_collage.jpg", file_stem));
    let file = File::create(&output_path)?;
    let mut encoder = JpegEncoder::new_with_quality(file, jpeg_quality);
    encoder.encode_image(&collage)?;

    println!("✨ {} finished in: {:?}", file_stem, total_start.elapsed());
    Ok(())
}