use anyhow::Result;
use crate::frb_generated::StreamSink;
use std::time::{Instant, Duration};
use std::path::Path;
use std::fs::File;
use video_rs::{Decoder, init};
use image::{RgbImage, codecs::jpeg::JpegEncoder};
use fast_image_resize as fr;
use fast_image_resize::images::Image;

pub async fn generate_collage(
    sink: StreamSink<String>, 
    paths: Vec<String>, 
    num_frames: i32, 
    quality: i32,
    threads_num: i32
) -> Result<()> {
    print!("Generating collage for {} files, threads: {}, quality: {}, frames: {}", paths.len(), threads_num, quality, num_frames);

    let total_elaboration_time = Instant::now();
    init().map_err(|e| anyhow::anyhow!("video-rs init error: {}", e))?;

    // Thread number taken from the flutter UI
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(threads_num as usize) 
        .build()?;

    pool.scope(|s| {
        for path in paths {
            let sink_inner = sink.clone();
            s.spawn(move |_| {
                if let Err(e) = generate_single_collage(&path, num_frames, quality) {
                    eprintln!("Error processing file {}: {}", path, e);
                } else {
                    // Notify Flutter side that this specific file is done
                    let _ = sink_inner.add(path); 
                }
            });
        }
    });

    println!("Batch completed in: {:?}", total_elaboration_time.elapsed());
    Ok(())
}

fn generate_single_collage(path: &str, num_frames: i32, _quality: i32) -> Result<()> {
    let total_start = Instant::now();
    let mut time_decoding = Duration::ZERO;
    let mut time_resizing = Duration::ZERO;
    
    let path_obj = Path::new(path);
    let file_stem = path_obj.file_stem().and_then(|s| s.to_str()).unwrap_or("video");

    let mut decoder = Decoder::new(path_obj)?;
    let (orig_w, orig_h) = decoder.size();
    let duration = decoder.duration()?.as_secs_f64();
    let interval = duration / (num_frames as f64);

    // Map quality levels to target resolution and jpeg compression
    let target_long_side = match _quality {
        0 => 320, 1 => 480, 2 => 640, 3 => 960, 4 => 1280,
        _ => 640,
    };
    let jpeg_quality = match _quality {
        0 => 50, 1 => 60, 2 => 70, 3 => 80, 4 => 90,
        _ => 70,
    };

    // Calculate aspect ratio maintained dimensions
    let (thumb_w, thumb_h) = if orig_h > orig_w {
        let scale = target_long_side as f32 / orig_h as f32;
        ((orig_w as f32 * scale) as u32, target_long_side as u32)
    } else {
        let scale = target_long_side as f32 / orig_w as f32;
        (target_long_side as u32, (orig_h as f32 * scale) as u32)
    };

    let mut extracted_images: Vec<RgbImage> = Vec::with_capacity(num_frames as usize);
    // Reuse resizer instance for all frames in this video
    let mut resizer = fr::Resizer::new();

    for i in 0..num_frames {
        let seek_ms = (i as f64 * interval * 1000.0) as i64;
        let start_dec = Instant::now();
        let _ = decoder.seek(seek_ms);

        if let Some(Ok(frame)) = decoder.decode_raw_iter().next() {
            let data = frame.data(0);
            let stride = frame.stride(0);
            time_decoding += start_dec.elapsed();

            let start_res = Instant::now();
            
            let u_w = orig_w as usize;
            let u_h = orig_h as usize;
            
            // Remove stride padding to get clean RGB data
            let mut clean_data = Vec::with_capacity(u_w * u_h * 3);
            for row in 0..u_h {
                let start = row * stride;
                let end = start + (u_w * 3);
                clean_data.extend_from_slice(&data[start..end]);
            }

            // Fast image resizing logic
            let src_image = Image::from_vec_u8(
                orig_w as u32,
                orig_h as u32,
                clean_data,
                fr::PixelType::U8x3,
            ).map_err(|e| anyhow::anyhow!("Failed to create src_image: {:?}", e))?;

            let mut dst_image = Image::new(
                thumb_w,
                thumb_h,
                fr::PixelType::U8x3,
            );

            resizer.resize(&src_image, &mut dst_image, &fr::ResizeOptions::new().resize_alg(fr::ResizeAlg::Nearest))
                .map_err(|e| anyhow::anyhow!("Resize failed: {:?}", e))?;

            if let Some(img) = RgbImage::from_raw(thumb_w, thumb_h, dst_image.into_vec()) {
                extracted_images.push(img);
            }
            
            time_resizing += start_res.elapsed();
        }
    }

    if extracted_images.is_empty() { return Err(anyhow::anyhow!("Zero frames extracted")); }

    // Assemble frames into a grid collage
    let start_grid = Instant::now();
    let columns = 8;
    let rows = (extracted_images.len() as u32 + columns - 1) / columns;
    let mut collage = RgbImage::new(thumb_w * columns, thumb_h * rows);
    
    let c_w = thumb_w * columns;
    let collage_samples = collage.as_flat_samples_mut().samples;

    for (i, img) in extracted_images.into_iter().enumerate() {
        let x_off = (i as u32 % columns) * thumb_w;
        let y_off = (i as u32 / columns) * thumb_h;
        let img_raw = img.as_raw();
        
        for y in 0..thumb_h {
            let src_start = (y * thumb_w * 3) as usize;
            let src_row = &img_raw[src_start..src_start + (thumb_w * 3) as usize];
            let dest_idx = (((y_off + y) * c_w + x_off) * 3) as usize;
            // Direct memory copy for grid assembly
            collage_samples[dest_idx..dest_idx + (thumb_w * 3) as usize].copy_from_slice(src_row);
        }
    }
    let time_grid = start_grid.elapsed();

    // Final export as JPEG
    let start_save = Instant::now();
    let output_path = path_obj.parent().unwrap().join(format!("{}_collage.jpg", file_stem));
    let file = File::create(&output_path)?;
    let writer = std::io::BufWriter::with_capacity(256 * 1024, file);
    
    let mut encoder = JpegEncoder::new_with_quality(writer, jpeg_quality);
    encoder.encode_image(&collage)?;
    let time_save = start_save.elapsed();

    println!(
        "File: {} | Decoding: {:?} | Resize: {:?} | Grid: {:?} | Save: {:?} | Total: {:?}",
        file_stem, time_decoding, time_resizing, time_grid, time_save, total_start.elapsed()
    );

    Ok(())
}