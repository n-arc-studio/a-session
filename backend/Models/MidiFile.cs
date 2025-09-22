using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ASession.Models
{
    public class MidiFile
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(200)]
        public string FileName { get; set; } = string.Empty;
        
        [Required]
        public string FilePath { get; set; } = string.Empty;
        
        public long FileSize { get; set; }
        
        [Required]
        public int SheetMusicId { get; set; }
        
        [Required]
        public int UploadedByUserId { get; set; }
        
        public bool IsLocked { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        [ForeignKey("SheetMusicId")]
        public virtual SheetMusic SheetMusic { get; set; } = null!;
        
        [ForeignKey("UploadedByUserId")]
        public virtual User UploadedByUser { get; set; } = null!;
        
        public virtual ICollection<Recording> Recordings { get; set; } = new List<Recording>();
    }
}
