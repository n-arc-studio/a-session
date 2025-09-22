using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace ASession.Models
{
    public class TeamMember
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public int TeamId { get; set; }
        
        [Required]
        public int UserId { get; set; }
        
        public bool IsLeader { get; set; } = false;
        
        public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
        
        // Navigation properties
        [ForeignKey("TeamId")]
        public virtual Team Team { get; set; } = null!;
        
        [ForeignKey("UserId")]
        public virtual User User { get; set; } = null!;
    }
}