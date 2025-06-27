import fitz  # PyMuPDF
import re
from paddleocr import PaddleOCR
import numpy as np
from PIL import Image
import io
import os

ocr = PaddleOCR(lang='en', enable_mkldnn = False)

def remove_nested_parens(input_str):
    """Remove all text inside parentheses, including nested ones, from input_str."""
    result = ''
    paren_level = 0
    for ch in input_str:
        if ch == '(':
            paren_level += 1
        elif ch == ')':
            if paren_level > 0:
                paren_level -= 1
        elif paren_level == 0:
            result += ch
    return result.strip()

def is_character_name(line):
    # Match character names with optional (CONT'D) or parentheticals
    # More specific pattern to avoid false positives
    clean_line = line.strip()
    return bool(re.match(r'^[A-Z][A-Z\s]+(?:\s*\(.*?\))?$', clean_line) and 
                len(clean_line.split()) <= 4 and  # Character names are usually short
                not re.match(r'^\(.*\)$', clean_line))  # Not just parentheses

def is_page_number(line):
    return re.fullmatch(r"\d+\.?", line.strip())

def is_stage_direction(line):
    """Check if line is a stage direction (text in parentheses)"""
    return re.match(r'^\s*\([^)]+\)\s*$', line.strip())

def detect_pdf_type(pdf_path, sample_pages=3):
    """
    Detect if PDF is text-based or image-based by checking text content
    Returns: 'text' or 'image'
    """
    doc = fitz.open(pdf_path)
    total_pages = len(doc)
    pages_to_check = min(sample_pages, total_pages)
    
    text_content_found = False
    
    for page_num in range(pages_to_check):
        page = doc[page_num]
        text = page.get_text("text", sort=True).strip()
        
        # If we find substantial text content (more than just page numbers)
        if text and len(text) > 20:
            # Check if it's not just page numbers or minimal content
            lines = text.splitlines()
            meaningful_lines = [line.strip() for line in lines if line.strip() and not is_page_number(line.strip())]
            
            if len(meaningful_lines) > 2:
                text_content_found = True
                break
    
    doc.close()
    return 'text' if text_content_found else 'image'

def extract_lines_from_page(page):
    """Extract lines from text-based PDF page"""
    text = page.get_text("text", sort=True).strip()
    if text:
        return text.splitlines()
    else:
        pix = page.get_pixmap()
        img = Image.open(io.BytesIO(pix.tobytes()))
        result = ocr.ocr(np.array(img))
        return [line[1][0] for line in result[0]] if result else []

def extract_lines_from_image_page(page):
    """Extract text from image-based PDF page using OCR with improved accuracy"""
    # Use higher resolution and better preprocessing for OCR
    pix = page.get_pixmap(matrix=fitz.Matrix(3, 3))  # Higher resolution
    img = Image.open(io.BytesIO(pix.tobytes()))
    
    # Convert to RGB if needed
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    result = ocr.ocr(np.array(img))
    
    if result and result[0]:
        # Extract and sort OCR results by vertical position
        ocr_results = []
        for line in result[0]:
            bbox = line[0]
            text_info = line[1]
            text = text_info[0]
            confidence = text_info[1]
            
            # Filter out low confidence results
            if confidence > 0.5:
                # Use center y-coordinate for better sorting
                y_coord = (bbox[0][1] + bbox[2][1]) / 2
                x_coord = (bbox[0][0] + bbox[2][0]) / 2
                ocr_results.append((y_coord, x_coord, text))
        
        # Sort by y-coordinate first, then x-coordinate for same line items
        ocr_results.sort(key=lambda x: (x[0], x[1]))
        
        # Group lines that are roughly on the same horizontal level
        grouped_lines = []
        current_group = []
        current_y = None
        y_threshold = 10  # pixels
        
        for y_coord, x_coord, text in ocr_results:
            if current_y is None or abs(y_coord - current_y) <= y_threshold:
                current_group.append((x_coord, text))
                current_y = y_coord if current_y is None else current_y
            else:
                # Sort current group by x-coordinate and join
                if current_group:
                    current_group.sort(key=lambda x: x[0])
                    line_text = ' '.join([text for _, text in current_group])
                    grouped_lines.append(line_text)
                current_group = [(x_coord, text)]
                current_y = y_coord
        
        # Don't forget the last group
        if current_group:
            current_group.sort(key=lambda x: x[0])
            line_text = ' '.join([text for _, text in current_group])
            grouped_lines.append(line_text)
        
        return grouped_lines
    
    return []

def clean_text(text):
    """Clean text but preserve essential formatting markers"""
    # Remove nested parentheses using iterative approach
    while True:
        new_text = re.sub(r'\([^()]*\)', '', text)
        if new_text == text:
            break
        text = new_text
    # Remove residual spaces and clean up
    text = remove_nested_parens(text)
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def extract_script(pdf_path):
    """
    Enhanced script extraction with better character dialogue detection
    """
    # Detect PDF type first
    pdf_type = detect_pdf_type(pdf_path)
    #print(f"PDF type detected: {pdf_type}")
    
    if pdf_type == 'image':
        return extract_script_from_image_pdf(pdf_path)
    
    # Process text-based PDF
    doc = fitz.open(pdf_path)
    output_blocks = []
    current_character = None
    current_dialogue = []
    current_narration = []

    for page_num, page in enumerate(doc):
        if page_num == 0:
            continue  # Skip title page

        lines = extract_lines_from_page(page)
        i = 0
        
        while i < len(lines):
            raw_line = lines[i].strip()
            
            # Skip empty lines and page numbers
            if not raw_line or is_page_number(raw_line):
                i += 1
                continue

            # Check if this is a character name
            if is_character_name(raw_line):
                # Flush any accumulated narration
                if current_narration:
                    1
                    # output_blocks.append(f"NARRATOR: {' '.join(current_narration)}")
                    # current_narration = []
                
                # Extract character name (remove any parentheticals for the name itself)
                current_character = re.sub(r'\s*\([^)]*\)', '', raw_line).strip().upper()
                i += 1
                
                # Collect dialogue lines for this character
                current_dialogue = []
                
                while i < len(lines):
                    next_raw_line = lines[i].strip()
                    
                    # Stop if we hit another character name or empty line
                    if not next_raw_line or is_character_name(next_raw_line):
                        break
                    
                    # Skip pure stage directions but include them in narration if substantial
                    if is_stage_direction(next_raw_line):
                        stage_direction = clean_text(next_raw_line)
                        if stage_direction:  # Only add non-empty stage directions
                            current_narration.append(stage_direction)
                    else:
                        # This is dialogue - clean it and add to current dialogue
                        clean_dialogue = clean_text(next_raw_line)
                        if clean_dialogue:
                            current_dialogue.append(clean_dialogue)
                    
                    i += 1
                
                # Add the character's dialogue block if we have dialogue
                if current_character and current_dialogue:
                    output_blocks.append(f"{current_character}: {' '.join(current_dialogue)}")
                
                continue
            
            # This line is narration/action
            clean_line = clean_text(raw_line)
            if clean_line:
                current_narration.append(clean_line)
            i += 1

    # Add any remaining narration
    if current_narration:
        1
        # output_blocks.append(f"NARRATOR: {' '.join(current_narration)}")

    doc.close()
    return '\n'.join(output_blocks)

def extract_script_from_image_pdf(pdf_path):
    """
    Enhanced script extraction for image-based PDFs with better OCR handling
    """
    doc = fitz.open(pdf_path)
    output_blocks = []
    current_character = None
    current_dialogue = []
    current_narration = []

    for page_num, page in enumerate(doc):
        if page_num == 0:
            continue  # Skip title page

        lines = extract_lines_from_image_page(page)
        i = 0
        
        while i < len(lines):
            raw_line = lines[i].strip()
            
            # Skip empty lines and page numbers
            if not raw_line or is_page_number(raw_line):
                i += 1
                continue

            # Enhanced character name detection for OCR text
            if is_character_name(raw_line) or is_likely_character_name_ocr(raw_line):
                # Flush any accumulated narration
                if current_narration:
                    output_blocks.append(f"NARRATOR: {' '.join(current_narration)}")
                    current_narration = []
                
                # Extract character name
                current_character = re.sub(r'\s*\([^)]*\)', '', raw_line).strip().upper()
                i += 1
                
                # Collect dialogue lines for this character
                current_dialogue = []
                
                while i < len(lines):
                    next_raw_line = lines[i].strip()
                    
                    # Stop if we hit another character name or empty line
                    if (not next_raw_line or 
                        is_character_name(next_raw_line) or 
                        is_likely_character_name_ocr(next_raw_line)):
                        break
                    
                    # Process the line
                    if is_stage_direction(next_raw_line):
                        stage_direction = clean_text(next_raw_line)
                        if stage_direction:
                            current_narration.append(stage_direction)
                    else:
                        clean_dialogue = clean_text(next_raw_line)
                        if clean_dialogue:
                            current_dialogue.append(clean_dialogue)
                    
                    i += 1
                
                # Add the character's dialogue block
                if current_character and current_dialogue:
                    output_blocks.append(f"{current_character}: {' '.join(current_dialogue)}")
                
                continue
            
            # This line is narration/action
            clean_line = clean_text(raw_line)
            if clean_line:
                current_narration.append(clean_line)
            i += 1

    # Add any remaining narration
    if current_narration:
        output_blocks.append(f"NARRATOR: {' '.join(current_narration)}")

    doc.close()
    return '\n'.join(output_blocks)

def is_likely_character_name_ocr(line):
    """
    Additional character name detection for OCR text which might have spacing issues
    """
    line = line.strip()
    if not line:
        return False
    
    # Check for common character name patterns that OCR might produce
    # All caps words, possibly with some lowercase due to OCR errors
    words = line.split()
    if len(words) <= 3:  # Character names are usually 1-3 words
        # Check if most characters are uppercase
        alpha_chars = ''.join([c for c in line if c.isalpha()])
        if alpha_chars:
            uppercase_ratio = sum(1 for c in alpha_chars if c.isupper()) / len(alpha_chars)
            if uppercase_ratio > 0.7:  # 70% or more uppercase
                return True
    
    return False

def get_unique_characters(script_text):
    """
    Extracts and returns a list of all unique character names from the script text.
    Assumes each dialogue line starts with CHARACTER_NAME: dialogue.
    """
    characters = set()
    for line in script_text.splitlines():
        if ':' in line:
            character = line.split(':', 1)[0].strip().upper()
            characters.add(character)
    return list(characters)


def script_without_character(script_text, character_name):
    """
    Remove all dialogue lines spoken by the given character.
    """
    character_name = character_name.strip().upper() + ":"
    filtered_lines = [
        line for line in script_text.splitlines()
        if not line.startswith(character_name)
    ]
    return "\n".join(filtered_lines)

def script_with_character(script_text, character):
    """
    Returns a string containing only the dialogue lines spoken by the specified character.
    Assumes each dialogue line starts with CHARACTER_NAME: dialogue.
    """
    character_prefix = character.strip().upper() + ":"
    selected_lines = [
        line for line in script_text.splitlines()
        if line.startswith(character_prefix)
    ]
    return "\n".join(selected_lines)


# Example usage:
if __name__ == "__main__":
    # Suppose you have already extracted the script text
    script_text = extract_script("F:/ML/ST/app/Selftape-AI/backend/scripts/AftertheTrade.pdf")  # Your existing extraction function

    script=script_with_character(script_text, "PAMELA")



# Save or use filtered_script as needed

# Usage
# if __name__ == "__main__":
#     # Example usage - replace with your PDF path
#     pdf_path = "scripts/AftertheTrade.pdf"  # Change this to your PDF path
    
#     try:
#         script_text = extract_script(pdf_path)
        
#         # Save to file
#         output_filename = "formatted_script.txt"
#         with open(output_filename, "w", encoding="utf-8") as f:
#             f.write(script_text)
        
#         # print(f"Script extraction completed! Output saved to {output_filename}")
#         # print(f"Extracted {len(script_text.splitlines())} lines of script content.")
        
#         # # Print first few lines for debugging
#         # print("\nFirst few lines of output:")
#         # for i, line in enumerate(script_text.splitlines()[:10]):
#         #     print(f"{i+1}: {line}")
        
#     except Exception as e:
#         print(f"Error processing PDF: {str(e)}")