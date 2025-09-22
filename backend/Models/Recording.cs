using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ASession.Models
{
    public class Recording
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(200)]
        public string FileName { get; set; } = string.Empty;
        
        [Required]
        public string FilePath { get; set; } = string.Empty;
        
        public long FileSize { get; set; }
        
        [MaxLength(50)]
        public string AudioFormat { get; set; } = string.Empty; // MP3, WAV, etc.
        
        public int? MidiFileId { get; set; } // nullable for standalone recordings
        
        [Required]
        public int RecordedByUserId { get; set; }
        
        public DateTime RecordingDate { get; set; } = DateTime.UtcNow;
        
        [MaxLength(500)]
        public string? Notes { get; set; }
        
        public bool IsShared { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        [ForeignKey("MidiFileId")]
        public virtual MidiFile? MidiFile { get; set; }
        
        [ForeignKey("RecordedByUserId")]
        public virtual User RecordedByUser { get; set; } = null!;
    }
}
