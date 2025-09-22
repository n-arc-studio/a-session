using System.ComponentModel.DataAnnotations;

namespace ASession.Models
{
    public class User
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        [MaxLength(100)]
        public string Name { get; set; } = string.Empty;
        
        [Required]
        [EmailAddress]
        [MaxLength(200)]
        public string Email { get; set; } = string.Empty;
        
        public string? GoogleId { get; set; }
        public string? AppleId { get; set; }
        
        public bool IsLocked { get; set; } = false;
        public bool IsAdmin { get; set; } = false;
        
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        public virtual ICollection<TeamMember> TeamMembers { get; set; } = new List<TeamMember>();
        public virtual ICollection<SheetMusic> CreatedSheetMusics { get; set; } = new List<SheetMusic>();
        public virtual ICollection<Recording> Recordings { get; set; } = new List<Recording>();
    }
}