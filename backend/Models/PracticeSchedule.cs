using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ASession.Models
{
    public class PracticeSchedule
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(200)]
        public string Title { get; set; } = string.Empty;
        
        [MaxLength(1000)]
        public string? Description { get; set; }
        
        [Required]
        public int TeamId { get; set; }
        
        [Required]
        public int CreatedByUserId { get; set; }
        
        [Required]
        public DateTime ScheduledDate { get; set; }
        
        [Required]
        public TimeSpan StartTime { get; set; }
        
        [Required]
        public TimeSpan EndTime { get; set; }
        
        [MaxLength(200)]
        public string? Location { get; set; }
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        [ForeignKey("TeamId")]
        public virtual Team Team { get; set; } = null!;
        
        [ForeignKey("CreatedByUserId")]
        public virtual User CreatedByUser { get; set; } = null!;
    }
}