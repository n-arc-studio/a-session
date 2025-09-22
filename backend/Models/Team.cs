using System.ComponentModel.DataAnnotations;

namespace ASession.Models
{
    public class Team
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
        
        [MaxLength(500)]
        public string? Description { get; set; }
        
        public bool IsLocked { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        public virtual ICollection<TeamMember> TeamMembers { get; set; } = new List<TeamMember>();
        public virtual ICollection<SheetMusic> SheetMusics { get; set; } = new List<SheetMusic>();
        public virtual ICollection<PracticeSchedule> PracticeSchedules { get; set; } = new List<PracticeSchedule>();
    }
}
