using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ASession.Models
{
    public class SheetMusic
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(200)]
        public string Title { get; set; } = string.Empty;
        
        [MaxLength(100)]
        public string? Composer { get; set; }
        
        [MaxLength(100)]
        public string? Arranger { get; set; }
        
        [Required]
        public string FilePath { get; set; } = string.Empty;
        
        [MaxLength(50)]
        public string FileType { get; set; } = string.Empty; // PDF, MusicXML, etc.
        
        public long FileSize { get; set; }
        
        [Required]
        public int TeamId { get; set; }
        
        [Required]
        public int CreatedByUserId { get; set; }
        
        public bool IsLocked { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        [ForeignKey("TeamId")]
        public virtual Team Team { get; set; } = null!;
        
        [ForeignKey("CreatedByUserId")]
        public virtual User CreatedByUser { get; set; } = null!;
        
        public virtual ICollection<MidiFile> MidiFiles { get; set; } = new List<MidiFile>();
    }
}
